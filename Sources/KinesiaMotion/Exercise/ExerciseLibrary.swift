//
//  ExerciseLibrary.swift
//  KinesiaMotion
//
//  Created by Deivy Mejia Ruiz on 4/10/26.
//

import Foundation

/// The built-in catalog. Each exercise is data, not code: adding one never touches the engine.
public enum ExerciseLibrary {

    /// Elbow flexion, standing, seen from the side.
    /// Form: the upper arm stays by the body, so the shoulder can't do the work.
    public static let elbowFlexion = ExerciseDefinition(
        id: "elbow.flexion",
        region: .elbow,
        view: .side,
        kind: .reps(low: 30, high: 90),
        primary: .flexion(a: "shoulder", vertex: "elbow", b: "wrist"),
        rules: [
            FormRule(
                feedback: .keepUpperArmStill,
                measure: .fromVertical(from: "shoulder", to: "elbow"),
                allowed: 0...30
            )
        ],
        defaultTarget: 120
    )

    /// Standing knee flexion (heel to glute), seen from the side.
    /// Form: the thigh stays vertical and the trunk upright, so it isn't a squat or a lean.
    public static let kneeFlexionStanding = ExerciseDefinition(
        id: "knee.flexion.standing",
        region: .knee,
        view: .side,
        kind: .reps(low: 20, high: 60),
        primary: .flexion(a: "hip", vertex: "knee", b: "ankle"),
        rules: [
            FormRule(
                feedback: .keepThighStill,
                measure: .fromVertical(from: "hip", to: "knee"),
                allowed: 0...25
            ),
            FormRule(
                feedback: .keepTrunkUpright,
                measure: .fromVertical(from: "shoulder", to: "hip"),
                allowed: 0...20
            )
        ],
        defaultTarget: 110
    )

    // MARK: - Shoulder

    /// Shoulder flexion (arm forward and up), standing, seen from the side.
    /// Form: the elbow stays straight and the trunk doesn't lean back to fake height.
    public static let shoulderFlexion = ExerciseDefinition(
        id: "shoulder.flexion",
        region: .shoulder,
        view: .side,
        kind: .reps(low: 30, high: 90),
        primary: .fromVertical(from: "shoulder", to: "elbow"),
        rules: [
            FormRule(
                feedback: .keepElbowStraight,
                measure: .flexion(a: "shoulder", vertex: "elbow", b: "wrist"),
                allowed: 0...25
            ),
            FormRule(
                feedback: .keepTrunkUpright,
                measure: .fromVertical(from: "shoulder", to: "hip"),
                allowed: 0...15
            )
        ],
        defaultTarget: 160
    )

    /// Shoulder abduction (arm out to the side and up), standing, seen from the front.
    /// Form: elbow straight, no shrugging and no leaning to the other side.
    public static let shoulderAbduction = ExerciseDefinition(
        id: "shoulder.abduction",
        region: .shoulder,
        view: .front,
        kind: .reps(low: 30, high: 90),
        primary: .fromVertical(from: "shoulder", to: "elbow"),
        rules: [
            FormRule(
                feedback: .keepElbowStraight,
                measure: .flexion(a: "shoulder", vertex: "elbow", b: "wrist"),
                allowed: 0...25
            ),
            FormRule(
                feedback: .keepShouldersLevel,
                measure: .tilt(a: "shoulder", b: "opposite.shoulder"),
                allowed: 0...15
            ),
            FormRule(
                feedback: .keepTrunkUpright,
                measure: .fromVertical(from: "shoulder", to: "hip"),
                allowed: 0...15
            )
        ],
        defaultTarget: 160
    )

    /// Shoulder extension (straight arm back behind the body), standing, seen from the side.
    /// The angle has no direction, so the arm must go back, as the app asks.
    /// Form: elbow straight and the trunk doesn't lean forward to add degrees.
    public static let shoulderExtension = ExerciseDefinition(
        id: "shoulder.extension",
        region: .shoulder,
        view: .side,
        kind: .reps(low: 15, high: 30),
        primary: .fromVertical(from: "shoulder", to: "elbow"),
        rules: [
            FormRule(
                feedback: .keepElbowStraight,
                measure: .flexion(a: "shoulder", vertex: "elbow", b: "wrist"),
                allowed: 0...25
            ),
            FormRule(
                feedback: .keepTrunkUpright,
                measure: .fromVertical(from: "shoulder", to: "hip"),
                allowed: 0...15
            )
        ],
        defaultTarget: 50
    )

    // MARK: - Hip

    /// Standing hip flexion with the knee bent (marching), seen from the side.
    /// Form: the trunk stays upright, so leaning back doesn't add degrees.
    public static let hipFlexionStanding = ExerciseDefinition(
        id: "hip.flexion.standing",
        region: .hip,
        view: .side,
        kind: .reps(low: 20, high: 50),
        primary: .fromVertical(from: "hip", to: "knee"),
        rules: [
            FormRule(
                feedback: .keepTrunkUpright,
                measure: .fromVertical(from: "shoulder", to: "hip"),
                allowed: 0...15
            )
        ],
        defaultTarget: 90
    )

    /// Standing hip abduction (leg out to the side), seen from the front.
    /// Form: knee straight, hips level (no hiking the pelvis) and trunk upright.
    public static let hipAbductionStanding = ExerciseDefinition(
        id: "hip.abduction.standing",
        region: .hip,
        view: .front,
        kind: .reps(low: 10, high: 20),
        primary: .fromVertical(from: "hip", to: "ankle"),
        rules: [
            FormRule(
                feedback: .keepKneeStraight,
                measure: .flexion(a: "hip", vertex: "knee", b: "ankle"),
                allowed: 0...20
            ),
            FormRule(
                feedback: .keepHipsLevel,
                measure: .tilt(a: "hip", b: "opposite.hip"),
                allowed: 0...10
            ),
            FormRule(
                feedback: .keepTrunkUpright,
                measure: .fromVertical(from: "shoulder", to: "hip"),
                allowed: 0...15
            )
        ],
        defaultTarget: 40
    )

    /// Standing hip extension (straight leg back), seen from the side, holding a chair.
    /// The angle has no direction, so the leg must go back, as the app asks.
    /// Form: knee straight and trunk upright: leaning forward is how the back fakes hip extension.
    public static let hipExtensionStanding = ExerciseDefinition(
        id: "hip.extension.standing",
        region: .hip,
        view: .side,
        kind: .reps(low: 8, high: 15),
        primary: .fromVertical(from: "hip", to: "ankle"),
        rules: [
            FormRule(
                feedback: .keepKneeStraight,
                measure: .flexion(a: "hip", vertex: "knee", b: "ankle"),
                allowed: 0...20
            ),
            FormRule(
                feedback: .keepTrunkUpright,
                measure: .fromVertical(from: "shoulder", to: "hip"),
                allowed: 0...15
            )
        ],
        defaultTarget: 20
    )

    // MARK: - Ankle

    /// Ankle dorsiflexion as a weight-bearing lunge, seen from the side, held at the end.
    /// 2D pose has no toe landmark, so we read the shin's forward lean (tibial inclination),
    /// which tracks dorsiflexion while the heel stays on the floor. The app must ask for that.
    public static let ankleDorsiflexionLunge = ExerciseDefinition(
        id: "ankle.dorsiflexion.lunge",
        region: .ankle,
        view: .side,
        kind: .hold(threshold: 15, seconds: 3),
        primary: .fromVertical(from: "knee", to: "ankle"),
        rules: [
            FormRule(
                feedback: .keepTrunkUpright,
                measure: .fromVertical(from: "shoulder", to: "hip"),
                allowed: 0...30
            )
        ],
        defaultTarget: 35
    )

    // MARK: - Neck

    /// Neck side bend (ear toward shoulder), seated or standing, seen from the front.
    /// Form: shoulders stay level, so the ear comes down instead of the shoulder going up.
    /// The tilt has no direction: run it once per side.
    public static let neckLateralFlexion = ExerciseDefinition(
        id: "neck.lateralFlexion",
        region: .neck,
        view: .front,
        kind: .reps(low: 10, high: 20),
        primary: .tilt(a: "ear", b: "opposite.ear"),
        rules: [
            FormRule(
                feedback: .keepShouldersLevel,
                measure: .tilt(a: "shoulder", b: "opposite.shoulder"),
                allowed: 0...10
            )
        ],
        defaultTarget: 40
    )

    // MARK: - Trunk

    /// Trunk forward bend (reach toward the floor), standing, seen from the side.
    /// 2D pose has no spine points, so we read the trunk's lean from vertical (shoulder over hip):
    /// it adds lumbar and hip flexion, like the inclinometer at the shoulders.
    /// Form: knees straight, so bending them doesn't buy depth.
    public static let trunkFlexion = ExerciseDefinition(
        id: "trunk.flexion",
        region: .back,
        view: .side,
        kind: .reps(low: 20, high: 45),
        primary: .fromVertical(from: "shoulder", to: "hip"),
        rules: [
            FormRule(
                feedback: .keepKneeStraight,
                measure: .flexion(a: "hip", vertex: "knee", b: "ankle"),
                allowed: 0...20
            )
        ],
        defaultTarget: 70
    )

    /// Trunk side bend (hand slides down the thigh), standing, seen from the front.
    /// Reads the midline (between the shoulders to between the hips) against vertical.
    /// The angle has no direction: run it once per side.
    /// Form: hips level, so the pelvis doesn't shift to fake the bend.
    public static let trunkLateralFlexion = ExerciseDefinition(
        id: "trunk.lateralFlexion",
        region: .back,
        view: .front,
        kind: .reps(low: 10, high: 20),
        primary: .fromVertical(from: "neck", to: "root"),
        rules: [
            FormRule(
                feedback: .keepHipsLevel,
                measure: .tilt(a: "hip", b: "opposite.hip"),
                allowed: 0...10
            )
        ],
        defaultTarget: 30
    )

    public static let all: [ExerciseDefinition] = [
        elbowFlexion,
        kneeFlexionStanding,
        shoulderFlexion,
        shoulderAbduction,
        hipFlexionStanding,
        hipAbductionStanding,
        ankleDorsiflexionLunge,
        neckLateralFlexion,
        shoulderExtension,
        hipExtensionStanding,
        trunkFlexion,
        trunkLateralFlexion
    ]

    public static func definition(id: String) -> ExerciseDefinition? {
        all.first { $0.id == id }
    }

    public static func definitions(for region: BodyRegion) -> [ExerciseDefinition] {
        all.filter { $0.region == region }
    }

    // MARK: - JSON

    /// Reads exercises from JSON: a file bundled with the app today, a download tomorrow.
    public static func decode(from data: Data) throws -> [ExerciseDefinition] {
        try JSONDecoder().decode([ExerciseDefinition].self, from: data)
    }

    public static func encode(_ definitions: [ExerciseDefinition]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(definitions)
    }
}
