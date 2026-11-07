//
//  VisionPoseProvider.swift
//  KinesiaMotion
//
//  Created by Deivy Mejia Ruiz on 4/10/26.
//

#if os(iOS)
import AVFoundation
import Vision
import KinesiaMotion

/// Live poses from the iPhone camera, using Vision's 2D body pose.
///
/// - The camera turns on when someone iterates `poses()` and off when they stop.
/// - Front camera: sides are un-mirrored here, so poses carry the patient's real left/right.
/// - Show `captureSession` in an `AVCaptureVideoPreviewLayer` for the live image.
/// - One stream at a time.
/// - `world: true` also runs Vision's 3D body pose, so poses carry 3D points and angles hold
///   when the patient isn't square to the camera. It costs more per frame.
public final class VisionPoseProvider: NSObject, PoseProvider, @unchecked Sendable {
    // @unchecked: AVCaptureSession isn't Sendable. All camera work runs on `queue`,
    // and the only state shared across threads (`continuation`) is guarded by `lock`.

    public enum Camera: Sendable {
        case front, back
    }

    /// Hand this to a preview layer.
    public let captureSession = AVCaptureSession()
    public let camera: Camera
    public let minimumConfidence: Float
    /// Poses also carry 3D points (Vision's 3D body pose).
    public let world: Bool

    private let queue = DispatchQueue(label: "kinesia.motion.vision")
    private let lock = NSLock()
    private let request = VNDetectHumanBodyPoseRequest()
    private let request3D = VNDetectHumanBodyPose3DRequest()
    private var continuation: AsyncStream<Pose>.Continuation?
    private var isConfigured = false

    public init(camera: Camera = .front, minimumConfidence: Float = 0.3, world: Bool = false) {
        self.camera = camera
        self.minimumConfidence = minimumConfidence
        self.world = world
        super.init()
    }

    // MARK: - Permission

    public static var isAuthorized: Bool {
        AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }

    public static func requestAccess() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }

    // MARK: - PoseProvider

    public func poses() -> AsyncStream<Pose> {
        // Keep only the newest pose: if the consumer is slow, old frames are useless.
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            setContinuation(continuation)

            queue.async { [self] in
                guard configureIfNeeded() else {
                    continuation.finish()
                    return
                }
                if !captureSession.isRunning { captureSession.startRunning() }
            }

            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                self.setContinuation(nil)
                self.queue.async { self.captureSession.stopRunning() }
            }
        }
    }

    // MARK: - Camera setup (runs on `queue`)

    private func configureIfNeeded() -> Bool {
        if isConfigured { return true }

        let position: AVCaptureDevice.Position = camera == .front ? .front : .back
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: device) else { return false }

        captureSession.beginConfiguration()
        captureSession.sessionPreset = .vga640x480
        if captureSession.canAddInput(input) { captureSession.addInput(input) }

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        if captureSession.canAddOutput(output) { captureSession.addOutput(output) }

        captureSession.commitConfiguration()
        isConfigured = true
        return true
    }

    // MARK: - Stream plumbing

    private func setContinuation(_ newValue: AsyncStream<Pose>.Continuation?) {
        lock.withLock { continuation = newValue }
    }

    private func yield(_ pose: Pose) {
        let current = lock.withLock { continuation }
        current?.yield(pose)
    }
}

// MARK: - Frames

extension VisionPoseProvider: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // Portrait: the sensor buffer is landscape, so the upright image is height × width.
        let imageSize = CGSize(
            width: CVPixelBufferGetHeight(pixelBuffer),
            height: CVPixelBufferGetWidth(pixelBuffer)
        )
        let isMirrored = camera == .front
        let orientation: CGImagePropertyOrientation = isMirrored ? .leftMirrored : .right
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds

        let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: orientation)
        try? handler.perform(world ? [request, request3D] : [request])

        yield(Pose(observation: request.results?.first,
                   observation3D: world ? request3D.results?.first : nil,
                   imageSize: imageSize,
                   timestamp: timestamp,
                   mirrored: isMirrored,
                   minimumConfidence: minimumConfidence))
    }
}
#endif
