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
    /// `observation3DMirrored`: whether the 3D request saw a mirror image (nil: same as `mirrored`).
    init(observation: VNHumanBodyPoseObservation?,
         observation3D: VNHumanBodyPose3DObservation? = nil,
         observation3DMirrored: Bool? = nil,
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
        let world = observation3D.map {
            Self.worldPoints(from: $0, matching: points, mirrored3D: observation3DMirrored ?? mirrored)
        } ?? [:]
        self.init(points: points, timestamp: timestamp, imageSize: imageSize,
                  confidence: confidence, world: world)
    }

    /// 3D points for the joints the 2D detector trusts, so both spaces see the same body.
    ///
    /// Sides come from Vision's joint names, which follow the image Vision saw: on a mirror image
    /// its "left" is the patient's right. Run 3D on the un-mirrored image and the names are
    /// already the patient's. (Matching by `pointInImage` gave too few joints on device.)
    static func worldPoints(from observation: VNHumanBodyPose3DObservation,
                            matching points: [Joint: CGPoint],
                            mirrored3D: Bool) -> [Joint: SIMD3<Double>] {
        var world: [Joint: SIMD3<Double>] = [:]
        for (name, detected) in Joint.vision3DNames {
            let joint = mirrored3D ? detected.mirrored : detected
            guard points[joint] != nil, let position = position(of: name, in: observation) else { continue }
            world[joint] = position
        }
        return world
    }

    /// Meters, y up. Camera space when Vision can place the camera; otherwise the body's own
    /// space (relative to the hips), which gives the same angles between segments.
    private static func position(of name: VNHumanBodyPose3DObservation.JointName,
                                 in observation: VNHumanBodyPose3DObservation) -> SIMD3<Double>? {
        let transform = (try? observation.cameraRelativePosition(name))
            ?? (try? observation.recognizedPoint(name))?.position
        guard let column = transform?.columns.3 else { return nil }
        return SIMD3(Double(column.x), Double(column.y), Double(column.z))
    }
}
