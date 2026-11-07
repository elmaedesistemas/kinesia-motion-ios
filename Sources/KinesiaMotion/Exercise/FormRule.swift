//
//  FormRule.swift
//  KinesiaMotion
//
//  Created by Deivy Mejia Ruiz on 4/10/26.
//

/// What went wrong with the form. The app turns each case into words and voice.
public enum FormFeedback: String, Sendable, CaseIterable, Codable {
    case keepUpperArmStill
    case keepThighStill
    case keepElbowStraight
    case keepTrunkUpright
    case keepShouldersLevel
    case keepKneeStraight
    case keepHipsLevel
}

/// A condition that must hold while a rep is in progress.
public struct FormRule: Sendable, Hashable, Codable {
    public let feedback: FormFeedback
    public let measure: Measure
    public let allowed: ClosedRange<Double>

    public init(feedback: FormFeedback, measure: Measure, allowed: ClosedRange<Double>) {
        self.feedback = feedback
        self.measure = measure
        self.allowed = allowed
    }

    /// nil when the joints aren't visible (we don't punish what we can't see).
    func isBroken(in pose: Pose, side: BodySide, space: MeasureSpace? = nil) -> Bool? {
        guard let value = measure.value(in: pose, side: side, preferring: space) else { return nil }
        return !allowed.contains(value)
    }
}
