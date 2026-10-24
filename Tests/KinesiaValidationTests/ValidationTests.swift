//
//  ValidationTests.swift
//  KinesiaMotion
//
//  Created by Deivy Mejia Ruiz on 24/10/26.
//

import Testing
import CoreGraphics
import Foundation
import KinesiaMotion
@testable import KinesiaValidation

@Suite("Goniometer validation")
struct ValidationTests {
    @Test("reads Spanish headers, aliases, sides and decimal commas")
    func parsesCSV() throws {
        let csv = """
        video,ejercicio,lado,goniometro,espejo
        # comments and empty lines are skipped

        codo-1.mov,codo,derecho,"132,5",no
        rodilla-1.mov,knee.flexion.standing,izq,95,si
        """
        let trials = try Validation.parseTrials(csv: csv)
        #expect(trials.count == 2)
        #expect(trials[0].exercise.id == "elbow.flexion")
        #expect(trials[0].side == .right)
        #expect(trials[0].goniometer == 132.5)
        #expect(trials[0].mirrored == false)
        #expect(trials[1].side == .left)
        #expect(trials[1].mirrored == true)
    }

    @Test("a wrong row says which line and why")
    func badRow() {
        let csv = "video,ejercicio,lado,goniometro\na.mov,codo,arriba,90"
        #expect(throws: Validation.CSVError.badRow(line: 1, reason: "lado «arriba»: usa izquierdo o derecho")) {
            try Validation.parseTrials(csv: csv)
        }
    }

    @Test("the peak is the median of the 5 highest frames, so one spike doesn't count")
    func peakIgnoresSpikes() throws {
        let flexions: [Double] = [10, 60, 110, 118, 119, 120, 121, 122, 170]   // 170 is a bad frame
        let poses = flexions.enumerated().map { elbowPose(flexion: $1, time: Double($0)) }
        let peak = try #require(Validation.peakAngle(in: poses, exercise: ExerciseLibrary.elbowFlexion, side: .right))
        #expect(abs(peak.angle - 121) < 0.5)
        #expect(peak.frames == 9)
    }

    @Test("no visible joints gives no peak")
    func noJoints() {
        let empty = [Pose(points: [:], timestamp: 0)]
        #expect(Validation.peakAngle(in: empty, exercise: ExerciseLibrary.elbowFlexion, side: .right) == nil)
    }

    @Test("summary: mean absolute error, bias, share within ±5° and pass/fail")
    func summary() throws {
        let trial = { (goniometer: Double) in
            ValidationTrial(video: "x.mov", exercise: ExerciseLibrary.elbowFlexion, side: .right, goniometer: goniometer)
        }
        let results = [
            ValidationResult(trial: trial(100), kinesia: 103, measuredFrames: 30),   // +3
            ValidationResult(trial: trial(120), kinesia: 116, measuredFrames: 30),   // −4
            ValidationResult(trial: trial(90), kinesia: 98, measuredFrames: 30),     // +8
            ValidationResult(trial: trial(110), kinesia: nil, measuredFrames: 0),    // not measured
        ]
        let summary = try #require(Validation.summarize(results).first)
        #expect(summary.trials == 4)
        #expect(summary.failedTrials == 1)
        #expect(abs((summary.meanAbsoluteError ?? 0) - 5) < 0.001)
        #expect(abs((summary.bias ?? 0) - 7.0 / 3) < 0.001)
        #expect(summary.maxAbsoluteError == 8)
        #expect(abs((summary.withinTolerance ?? 0) - 2.0 / 3) < 0.001)
        #expect(summary.passes)
    }

    /// Right arm with an exact elbow flexion. y grows downward.
    private func elbowPose(flexion: Double, time: TimeInterval) -> Pose {
        let r = Double.pi / 180
        let shoulder = CGPoint(x: 0, y: 0)
        let elbow = CGPoint(x: 0, y: 100)
        let wrist = CGPoint(x: elbow.x + 100 * sin(flexion * r), y: elbow.y + 100 * cos(flexion * r))
        return Pose(points: [.rightShoulder: shoulder, .rightElbow: elbow, .rightWrist: wrist], timestamp: time)
    }
}
