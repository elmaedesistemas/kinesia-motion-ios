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
            Self.worldPoints(from: $0, matching: points, imageSize: imageSize,
                             mirrored3D: observation3DMirrored ?? mirrored, mirrored2D: mirrored)
        } ?? [:]
        self.init(points: points, timestamp: timestamp, imageSize: imageSize,
                  confidence: confidence, world: world)
    }

    /// 3D points for the joints the 2D detector trusts, so both spaces see the same body.
    ///
    /// The side of each 3D joint is taken from where it lands in the image: it goes to the 2D
    /// joint (left or right) it sits on. That holds whatever left/right convention Vision's 3D
    /// model uses with a mirrored image, where naming alone could put the arm on the wrong side.
    static func worldPoints(from observation: VNHumanBodyPose3DObservation,
                            matching points: [Joint: CGPoint],
                            imageSize: CGSize,
                            mirrored3D: Bool,
                            mirrored2D: Bool) -> [Joint: SIMD3<Double>] {
        var world: [Joint: SIMD3<Double>] = [:]
        for (name, detected) in Joint.vision3DNames {
            let named = mirrored3D ? detected.mirrored : detected
            let inImage = (try? observation.pointInImage(name)).map {
                // Into the 2D image: flip x when only one of the two images is a mirror image.
                let x = mirrored3D == mirrored2D ? $0.location.x : 1 - $0.location.x
                return CGPoint(x: x * imageSize.width, y: (1 - $0.location.y) * imageSize.height)
            }
            guard let joint = side(for: named, at: inImage, in: points, imageSize: imageSize),
                  let position = position(of: name, in: observation) else { continue }
            world[joint] = position
        }
        return world
    }

    /// Which 2D joint a 3D joint belongs to: `named` or its mirror, whichever 2D point is nearer
    /// to where the 3D joint lands in the image. nil when neither is in view (or too far away).
    static func side(for named: Joint, at inImage: CGPoint?, in points: [Joint: CGPoint],
                     imageSize: CGSize) -> Joint? {
        let candidates = Set([named, named.mirrored]).filter { points[$0] != nil }
        guard let inImage else {
            // No image position to compare: trust the name.
            return points[named] != nil ? named : nil
        }
        let maximum = 0.25 * max(imageSize.width, imageSize.height)
        return candidates
            .map { ($0, hypot(points[$0]!.x - inImage.x, points[$0]!.y - inImage.y)) }
            .filter { $0.1 <= maximum }
            .min { $0.1 < $1.1 }?
            .0
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
