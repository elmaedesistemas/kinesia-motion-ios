//
//  MotionSession.swift
//  KinesiaMotion
//
//  Created by Deivy Mejia Ruiz on 4/10/26.
//

import Foundation
import Observation

/// The SDK's front door: connect a pose source, read `snapshot`, listen to `events()`.
///
/// ```swift
/// let session = MotionSession(exercise: ExerciseLibrary.elbowFlexion, side: .right)
/// session.start(with: camera)
/// for await event in session.events() { … }
/// ```
@available(iOS 17.0, *)
@available(macOS 14.0, *)
@MainActor
@Observable
public final class MotionSession {
    public private(set) var snapshot = MotionSnapshot()
    public private(set) var exercise: ExerciseDefinition
    public private(set) var side: BodySide
    /// Where angles are measured:
    /// - `.image`: 2D, on the camera image. Works with any pose source.
    /// - `.world`: 3D. Needs a source that gives world points (`VisionPoseProvider(world: true)`).
    /// - nil (default): 3D whenever the pose has it, 2D otherwise.
    /// Changing it applies from the next frame; the reps so far stay.
    public var space: MeasureSpace? {
        didSet { engine.space = space }
    }
    
    /// Peaks of the clean reps so far. Read it when saving a session.
    public var peaks: [Double] { engine.peaks }
    /// The clean reps so far, with their timing and confidence.
    public var reps: [Rep] { engine.reps }

    /// Frames in a row before visibility flips (~0.25 s at 24 FPS).
    @ObservationIgnored public var framesToConfirmVisibility = 6
    /// Thresholds for the placement check.
    @ObservationIgnored public var setupCheck = SetupCheck()
    /// Frames in a row before the placement issues change (~0.5 s at 24 FPS).
    @ObservationIgnored public var framesToConfirmSetup = 12

    @ObservationIgnored private var engine: RepEngine
    @ObservationIgnored private let smoothing: Double
    @ObservationIgnored private var visibilityStreak = 0
    @ObservationIgnored private var pendingSetup: Set<SetupIssue> = []
    @ObservationIgnored private var setupStreak = 0
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var listeners: [UUID: AsyncStream<MotionEvent>.Continuation] = [:]

    public init(exercise: ExerciseDefinition, side: BodySide, smoothing: Double = 0.5, space: MeasureSpace? = nil) {
        self.exercise = exercise
        self.side = side
        self.smoothing = smoothing
        self.space = space
        self.engine = Self.makeEngine(exercise, side, smoothing, space)
        snapshot.missingJoints = exercise.primary.joints(for: side)
    }

    // MARK: - Running

    /// Starts reading poses in the background. Calling it again replaces the previous source.
    public func start(with provider: some PoseProvider) {
        stop()
        task = Task { [weak self] in
            await self?.run(with: provider)
        }
    }

    /// Stops reading. The provider's stream ends, so a camera turns itself off.
    public func stop() {
        task?.cancel()
        task = nil
        snapshot.isRunning = false
    }

    /// Reads poses until the source ends or the task is cancelled.
    /// Use it when you manage the task yourself (and in tests).
    public func run(with provider: some PoseProvider) async {
        snapshot.isRunning = true
        for await pose in provider.poses() {
            if Task.isCancelled { break }
            process(pose)
        }
        snapshot.isRunning = false
    }

    /// Feeds one pose by hand. Returns what happened on this frame.
    @discardableResult
    public func process(_ pose: Pose) -> [MotionEvent] {
        var events = updateVisibility(with: pose)
        events += updateSetup(with: pose)
        events += engine.process(pose)

        snapshot.value = engine.value
        snapshot.best = engine.best
        snapshot.repCount = engine.count
        snapshot.rejectedCount = engine.rejected.count
        snapshot.holdProgress = engine.holdProgress
        snapshot.confidence = engine.confidence
        events += updateBaseline()

        for event in events {
            switch event {
            case .repCompleted(let rep), .repRejected(let rep):
                snapshot.lastRep = rep
            default:
                break
            }
            emit(event)
        }
        return events
    }

    // MARK: - Configuration

    /// Switches exercise or side and starts counting from zero.
    public func configure(exercise: ExerciseDefinition, side: BodySide) {
        self.exercise = exercise
        self.side = side
        reset()
    }

    /// Clears reps and values, keeps the source running.
    public func reset() {
        engine = Self.makeEngine(exercise, side, smoothing, space)
        visibilityStreak = 0
        pendingSetup = []
        setupStreak = 0
        let running = snapshot.isRunning
        snapshot = MotionSnapshot()
        snapshot.isRunning = running
        snapshot.missingJoints = requiredJoints
    }
    
    // MARK: - First measurement

    /// Starts a first measurement: counts from zero and finishes after `reps` clean reps
    /// (clean holds, for hold exercises).
    /// Rejected reps don't count, so the starting point is measured with good form.
    public func startBaseline(reps: Int = 3) {
        reset()
        snapshot.baseline = BaselineProgress(repsDone: 0, repsNeeded: reps, result: nil)
    }

    /// Finishes early with the clean reps done so far (at least one).
    public func finishBaseline() {
        guard var baseline = snapshot.baseline, !baseline.isFinished,
              let value = engine.peaks.median else { return }
        baseline.result = value
        snapshot.baseline = baseline
        emit(.baselineCompleted(value))
    }

    /// Leaves the first measurement without a result.
    public func cancelBaseline() {
        reset()
    }

    private func updateBaseline() -> [MotionEvent] {
        guard var baseline = snapshot.baseline, !baseline.isFinished else { return [] }

        baseline.repsDone = min(engine.count, baseline.repsNeeded)
        var events: [MotionEvent] = []

        if engine.count >= baseline.repsNeeded,
           let value = Array(engine.peaks.prefix(baseline.repsNeeded)).median {
            baseline.result = value
            events.append(.baselineCompleted(value))
        }

        snapshot.baseline = baseline
        return events
    }

    // MARK: - Events

    /// A new stream of events. Each caller gets its own; it ends when the caller stops listening.
    public func events() -> AsyncStream<MotionEvent> {
        let (stream, continuation) = AsyncStream.makeStream(
            of: MotionEvent.self,
            bufferingPolicy: .bufferingNewest(64)
        )
        let id = UUID()
        listeners[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in self?.listeners[id] = nil }
        }
        return stream
    }

    private func emit(_ event: MotionEvent) {
        for continuation in listeners.values {
            continuation.yield(event)
        }
    }

    // MARK: - Visibility

    private var requiredJoints: [Joint] {
        exercise.primary.joints(for: side)
    }

    private func updateVisibility(with pose: Pose) -> [MotionEvent] {
        let missing = requiredJoints.filter { pose[$0] == nil }
        let seesAll = missing.isEmpty

        guard seesAll != snapshot.isVisible else {
            visibilityStreak = 0
            if !seesAll { snapshot.missingJoints = missing }
            return []
        }

        visibilityStreak += 1
        guard visibilityStreak >= framesToConfirmVisibility else { return [] }

        visibilityStreak = 0
        snapshot.isVisible = seesAll
        snapshot.missingJoints = missing
        return [.visibilityChanged(Visibility(isVisible: seesAll, missingJoints: missing))]
    }

    // MARK: - Placement

    private func updateSetup(with pose: Pose) -> [MotionEvent] {
        let issues = setupCheck.issues(in: pose, exercise: exercise, side: side)

        guard issues != snapshot.setupIssues else {
            setupStreak = 0
            return []
        }

        if issues == pendingSetup {
            setupStreak += 1
        } else {
            pendingSetup = issues
            setupStreak = 1
        }
        guard setupStreak >= framesToConfirmSetup else { return [] }

        setupStreak = 0
        snapshot.setupIssues = issues
        return [.setupChanged(issues)]
    }

    // MARK: - Helpers

    private static func makeEngine(_ exercise: ExerciseDefinition, _ side: BodySide, _ smoothing: Double, _ space: MeasureSpace?) -> RepEngine {
        var engine = RepEngine(definition: exercise, side: side)
        engine.smoothing = smoothing
        engine.space = space
        return engine
    }
}
