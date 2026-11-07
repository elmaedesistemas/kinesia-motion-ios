//
//  Measure3DTests.swift
//  KinesiaMotion
//
//  Created by Deivy Mejia Ruiz on 6/11/26.
//

import CoreGraphics
import Testing
@testable import KinesiaMotion

/// A right arm with an exact elbow flexion, the upper arm hanging down, and the whole body
/// turned `turn` degrees away from the camera (around the vertical axis).
/// Returns the pose with its 2D points (the image the camera would see) and its 3D points.
private func turnedElbow(flexion: Double, turn: Double) -> Pose {
    let r = Double.pi / 180
    let shoulder = SIMD3<Double>(0, 0, 0)
    let elbow = SIMD3<Double>(0, -0.3, 0)
    // Forearm in the arm's own plane, then the plane turned around y.
    let forearm = SIMD3<Double>(sin(flexion * r) * cos(turn * r), -cos(flexion * r), -sin(flexion * r) * sin(turn * r))
    let wrist = elbow + forearm * 0.25

    // What the camera sees: drop depth, y grows downward, in "pixels".
    func image(_ p: SIMD3<Double>) -> CGPoint { CGPoint(x: p.x * 1000, y: -p.y * 1000) }

    return Pose(
        points: [.rightShoulder: image(shoulder), .rightElbow: image(elbow), .rightWrist: image(wrist)],
        timestamp: 0,
        world: [.rightShoulder: shoulder, .rightElbow: elbow, .rightWrist: wrist]
    )
}

@Suite("Measure in 3D")
struct Measure3DTests {
    private let elbow = Measure.flexion(a: "shoulder", vertex: "elbow", b: "wrist")

    @Test func geometry3DAngles() {
        #expect(isClose(Geometry3D.angle(at: .zero, SIMD3(1, 0, 0), SIMD3(0, 0, 1)), 90))
        #expect(isClose(Geometry3D.angle(at: .zero, SIMD3(-1, 0, 0), SIMD3(1, 0, 0)), 180))
        #expect(Geometry3D.angle(at: .zero, .zero, SIMD3(1, 0, 0)) == nil)
    }

    @Test func geometry3DFromVerticalUsesYUp() {
        #expect(isClose(Geometry3D.fromVertical(.zero, SIMD3(0, -1, 0)), 0))    // down
        #expect(isClose(Geometry3D.fromVertical(.zero, SIMD3(0, 0, 1)), 90))    // toward the camera
        #expect(isClose(Geometry3D.fromVertical(.zero, SIMD3(1, 0, 0)), 90))    // sideways
        #expect(isClose(Geometry3D.fromVertical(.zero, SIMD3(0, 1, 0)), 180))   // up
    }

    @Test func geometry3DTiltIgnoresDepth() {
        #expect(isClose(Geometry3D.tilt(.zero, SIMD3(1, 0, 1)), 0))
        #expect(isClose(Geometry3D.tilt(.zero, SIMD3(0, 1, 1)), 45))
        #expect(isClose(Geometry3D.tilt(.zero, SIMD3(0, 1, 0)), 90))
    }

    @Test func turnedPatientReadsWrongIn2DAndRightIn3D() throws {
        let pose = turnedElbow(flexion: 120, turn: 50)
        let image = try #require(elbow.imageValue(in: pose, side: .right))
        let world = try #require(elbow.worldValue(in: pose, side: .right))

        #expect(abs(image - 120) > 5)   // the camera sees a foreshortened forearm
        #expect(isClose(world, 120))
    }

    @Test func squarePatientReadsTheSameInBothSpaces() {
        let pose = turnedElbow(flexion: 120, turn: 0)
        #expect(isClose(elbow.imageValue(in: pose, side: .right), 120))
        #expect(isClose(elbow.worldValue(in: pose, side: .right), 120))
    }

    @Test func valuePrefers3DAndFallsBackToTheImage() {
        let pose = turnedElbow(flexion: 120, turn: 50)
        #expect(elbow.value(in: pose, side: .right) == elbow.worldValue(in: pose, side: .right))
        #expect(elbow.value(in: pose.imageOnly, side: .right) == elbow.imageValue(in: pose, side: .right))

        // One joint missing in 3D: the whole measure uses the image.
        var partial = pose
        partial.world[.rightWrist] = nil
        #expect(elbow.value(in: partial, side: .right) == elbow.imageValue(in: pose, side: .right))
    }

    @Test func forcedSpaceDoesNotFallBack() {
        let pose = turnedElbow(flexion: 120, turn: 50).imageOnly
        #expect(elbow.value(in: pose, side: .right, space: .world) == nil)
        #expect(elbow.value(in: pose, side: .right, space: .image) != nil)
    }

    @Test func engineMeasuresInTheChosenSpace() {
        let pose = turnedElbow(flexion: 120, turn: 50)
        func firstValue(_ space: MeasureSpace?) -> Double? {
            var engine = RepEngine(definition: ExerciseLibrary.elbowFlexion, side: .right)
            engine.space = space
            _ = engine.process(pose)
            return engine.value
        }
        #expect(firstValue(.image) == elbow.imageValue(in: pose, side: .right))
        #expect(firstValue(.world) == elbow.worldValue(in: pose, side: .right))
        #expect(firstValue(nil) == elbow.worldValue(in: pose, side: .right))

        // 3D forced but the pose has none: nothing is measured.
        var engine = RepEngine(definition: ExerciseLibrary.elbowFlexion, side: .right)
        engine.space = .world
        _ = engine.process(pose.imageOnly)
        #expect(engine.value == nil)
    }

    @Test @MainActor func sessionPassesItsSpaceToTheEngine() {
        let pose = turnedElbow(flexion: 120, turn: 50)
        let session = MotionSession(exercise: ExerciseLibrary.elbowFlexion, side: .right, space: .image)
        session.process(pose)
        #expect(session.snapshot.value == elbow.imageValue(in: pose, side: .right))

        session.space = .world
        session.reset()
        session.process(pose)
        #expect(session.snapshot.value == elbow.worldValue(in: pose, side: .right))
    }
}
