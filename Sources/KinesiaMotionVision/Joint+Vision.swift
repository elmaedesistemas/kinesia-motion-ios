//
//  Joint+Vision.swift
//  KinesiaMotion
//
//  Created by Deivy Mejia Ruiz on 4/10/26.
//

import Vision
import KinesiaMotion

/// Vision (iOS 18+) has its own `Joint` type. Inside this target, `Joint` always means ours.
typealias Joint = KinesiaMotion.Joint

extension Joint {
    /// Vision's 19 body joints mapped to ours, as Vision names them in the image.
    static let visionNames: [VNHumanBodyPoseObservation.JointName: Joint] = [
        .nose: .nose, .leftEye: .leftEye, .rightEye: .rightEye,
        .leftEar: .leftEar, .rightEar: .rightEar, .neck: .neck,
        .leftShoulder: .leftShoulder, .rightShoulder: .rightShoulder,
        .leftElbow: .leftElbow, .rightElbow: .rightElbow,
        .leftWrist: .leftWrist, .rightWrist: .rightWrist,
        .root: .root,
        .leftHip: .leftHip, .rightHip: .rightHip,
        .leftKnee: .leftKnee, .rightKnee: .rightKnee,
        .leftAnkle: .leftAnkle, .rightAnkle: .rightAnkle
    ]

    /// Vision's 3D body joints that match ours. The 3D model has no eyes, ears or nose;
    /// its center between the shoulders is our neck.
    static let vision3DNames: [VNHumanBodyPose3DObservation.JointName: Joint] = [
        .centerShoulder: .neck,
        .leftShoulder: .leftShoulder, .rightShoulder: .rightShoulder,
        .leftElbow: .leftElbow, .rightElbow: .rightElbow,
        .leftWrist: .leftWrist, .rightWrist: .rightWrist,
        .root: .root,
        .leftHip: .leftHip, .rightHip: .rightHip,
        .leftKnee: .leftKnee, .rightKnee: .rightKnee,
        .leftAnkle: .leftAnkle, .rightAnkle: .rightAnkle
    ]

    /// Converts a Vision joint into the patient's anatomical joint.
    /// With a mirrored image (front camera), Vision's "left" is the patient's real right.
    init?(visionName: VNHumanBodyPoseObservation.JointName, mirrored: Bool) {
        guard let joint = Self.visionNames[visionName] else { return nil }
        self = mirrored ? joint.mirrored : joint
    }

    /// Same landmark on the other side. Midline joints stay the same.
    var mirrored: Joint {
        switch self {
        case .leftEye: .rightEye
        case .rightEye: .leftEye
        case .leftEar: .rightEar
        case .rightEar: .leftEar
        case .leftShoulder: .rightShoulder
        case .rightShoulder: .leftShoulder
        case .leftElbow: .rightElbow
        case .rightElbow: .leftElbow
        case .leftWrist: .rightWrist
        case .rightWrist: .leftWrist
        case .leftHip: .rightHip
        case .rightHip: .leftHip
        case .leftKnee: .rightKnee
        case .rightKnee: .leftKnee
        case .leftAnkle: .rightAnkle
        case .rightAnkle: .leftAnkle
        case .nose, .neck, .root: self
        }
    }
}
