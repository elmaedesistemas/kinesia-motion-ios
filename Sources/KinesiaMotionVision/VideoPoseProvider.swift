//
//  VideoPoseProvider.swift
//  KinesiaMotion
//
//  Created by Deivy Mejia Ruiz on 24/10/26.
//

import AVFoundation
import Vision
import KinesiaMotion

/// Poses from a video file, with the same Vision body pose as the live camera.
///
/// - Runs on the device that has the file: nothing is uploaded.
/// - Reads iPhone videos in any orientation (it follows the track's rotation).
/// - `mirrored`: pass `true` when the video shows the patient as a mirror does (a selfie
///   recording that kept the preview's flip). Sides are then swapped to the patient's real ones.
/// - Without `realTime`, frames go out as fast as Vision reads them: good for tests and analysis.
/// - `world: true` also runs Vision's 3D body pose, so poses carry 3D points.
/// - Use `readAll()` to get every pose at once, for example to build a `RecordedPoseProvider`.
public struct VideoPoseProvider: PoseProvider {
    public let url: URL
    public let mirrored: Bool
    public let minimumConfidence: Float
    /// Frames closer together than 1 / maximumFrameRate are skipped. Vision is the slow part.
    public let maximumFrameRate: Double
    /// Waits between frames as in the video, like the live camera would.
    public let realTime: Bool
    /// Poses also carry 3D points (Vision's 3D body pose).
    public let world: Bool

    public init(url: URL,
                mirrored: Bool = false,
                minimumConfidence: Float = 0.3,
                maximumFrameRate: Double = 30,
                realTime: Bool = false,
                world: Bool = false) {
        self.url = url
        self.mirrored = mirrored
        self.minimumConfidence = minimumConfidence
        self.maximumFrameRate = maximumFrameRate
        self.realTime = realTime
        self.world = world
    }

    public enum ReadError: Error, Sendable {
        case noVideoTrack
        case cannotRead(String)
    }

    // MARK: - PoseProvider

    /// Ends when the video ends, when it can't be read, or when the consumer stops.
    public func poses() -> AsyncStream<Pose> {
        AsyncStream { continuation in
            let task = Task {
                try? await read { pose in
                    continuation.yield(pose)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Every pose in the video, in order. Throws when the file can't be read.
    public func readAll() async throws -> [Pose] {
        var all: [Pose] = []
        try await read { all.append($0) }
        return all
    }

    // MARK: - Reading

    private func read(_ handle: (Pose) async -> Void) async throws {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw ReadError.noVideoTrack
        }
        let (transform, naturalSize) = try await track.load(.preferredTransform, .naturalSize)
        let (orientation, imageSize) = Self.upright(transform: transform, naturalSize: naturalSize)

        let reader: AVAssetReader
        do {
            reader = try AVAssetReader(asset: asset)
        } catch {
            throw ReadError.cannotRead(error.localizedDescription)
        }
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        ])
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { throw ReadError.cannotRead("Can't add the video output") }
        reader.add(output)
        guard reader.startReading() else {
            throw ReadError.cannotRead(reader.error?.localizedDescription ?? "Can't start reading")
        }
        defer { reader.cancelReading() }

        let request = VNDetectHumanBodyPoseRequest()
        let request3D = VNDetectHumanBodyPose3DRequest()
        let minimumGap = maximumFrameRate > 0 ? 1 / maximumFrameRate : 0
        var lastTimestamp: TimeInterval?

        while !Task.isCancelled, let sample = output.copyNextSampleBuffer() {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sample) else { continue }
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sample).seconds
            if let lastTimestamp, timestamp - lastTimestamp < minimumGap - 0.001 { continue }

            if realTime, let lastTimestamp {
                try? await Task.sleep(for: .seconds(max(timestamp - lastTimestamp, 0)))
            }
            lastTimestamp = timestamp

            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation)
            try? handler.perform([request])
            var error3D: Error?
            if world {
                do { try handler.perform([request3D]) } catch { error3D = error }
            }

            let pose = Pose(observation: request.results?.first,
                            observation3D: world ? request3D.results?.first : nil,
                            imageSize: imageSize,
                            timestamp: timestamp,
                            mirrored: mirrored,
                            minimumConfidence: minimumConfidence)
            if world { Vision3DLog.report(error: error3D, bodies: request3D.results?.count ?? 0, pose: pose) }
            await handle(pose)
        }

        if reader.status == .failed {
            throw ReadError.cannotRead(reader.error?.localizedDescription ?? "Reading failed")
        }
    }

    /// iPhone videos are stored sideways with a rotation to apply. Vision needs that rotation,
    /// and points are measured in the upright image.
    static func upright(transform: CGAffineTransform,
                        naturalSize: CGSize) -> (CGImagePropertyOrientation, CGSize) {
        let degrees = (atan2(transform.b, transform.a) * 180 / .pi).rounded()
        let swapped = CGSize(width: naturalSize.height, height: naturalSize.width)
        switch degrees {
        case 90: return (.right, swapped)
        case -90: return (.left, swapped)
        case 180, -180: return (.down, naturalSize)
        default: return (.up, naturalSize)
        }
    }
}
