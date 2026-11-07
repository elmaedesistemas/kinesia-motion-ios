//
//  Pose+Vision.swift
//  KinesiaMotion
//
//  Created by Deivy Mejia Ruiz on 24/10/26.
//

import CoreGraphics
import Vision
import KinesiaMotion

extension Pose {
    /// One Vision result as a `Pose`: pixels in the upright image, y down, sides as the patient's.
    /// No observation gives an empty pose, which tells the session the person left the frame.
    /// `observation3D` adds world points (meters, y up) for the joints seen in 2D.
    init(observation: VNHumanBodyPoseObservation?,
         observation3D: VNHumanBodyPose3DObservation? = nil,
         imageSize: CGSize,
         timestamp: TimeInterval,
         mirrored: Bool,
         minimumConfidence: Float) {
        var points: [Joint: CGPoint] = [:]
        var confidence: [Joint: Double] = [:]
        if let observation, let recognized = try? observation.recognizedPoints(.all) {
            for (name, point) in recognized where point.confidence > minimumConfidence {
                guard let joint = Joint(visionName: name, mirrored: mirrored) else { continue }
                // Vision: normalized, origin bottom-left. Pose: pixels, y grows downward.
                points[joint] = CGPoint(
                    x: point.location.x * imageSize.width,
                    y: (1 - point.location.y) * imageSize.height
                )
                confidence[joint] = Double(point.confidence)
            }
        }
        var world: [Joint: SIMD3<Double>] = [:]
        if let observation3D {
            for (name, detected) in Joint.vision3DNames {
                let joint = mirrored ? detected.mirrored : detected
                // Only joints the 2D detector trusts, so both spaces see the same body.
                guard points[joint] != nil,
                      let transform = try? observation3D.cameraRelativePosition(name) else { continue }
                // Camera space: meters, y up with the image upright. A mirrored image flips x,
                // which doesn't change any angle.
                let position = transform.columns.3
                world[joint] = SIMD3(Double(position.x), Double(position.y), Double(position.z))
            }
        }
        self.init(points: points, timestamp: timestamp, imageSize: imageSize,
                  confidence: confidence, world: world)
    }
}
