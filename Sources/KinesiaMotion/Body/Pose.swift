//
//  Pose.swift
//  KinesiaMotion
//
//  Created by Deivy Mejia Ruiz on 4/10/26.
//

import CoreGraphics
import Foundation

/// One frame of body landmarks.
///
/// Contract (the adapter that builds poses must respect it):
/// - Coordinates are in image pixels, with y growing **downward**.
/// - Sides are **anatomical**: the patient's real left and right, already un-mirrored.
/// - Only confident points are included (low-confidence joints are left out).
/// - `confidence` is optional: a source that doesn't know leaves it empty.
/// - `world` is optional too: 3D positions for the same joints, in meters, with y pointing **up**
///   (the camera held upright). The origin depends on the source; only directions matter.
///   A world point is only given for a joint that is also in `points`.
public struct Pose: Sendable {
    public var points: [Joint: CGPoint]
    /// 3D positions in meters, y up. Empty when the source only sees the image.
    /// When a measure has every joint it needs here, it is measured in 3D.
    public var world: [Joint: SIMD3<Double>]
    public var timestamp: TimeInterval
    /// Size of the image the points were measured in. Lets a UI draw them over the camera.
    public var imageSize: CGSize?
    /// How sure the detector is of each point, 0...1.
    public var confidence: [Joint: Double]

    public init(
        points: [Joint: CGPoint],
        timestamp: TimeInterval,
        imageSize: CGSize? = nil,
        confidence: [Joint: Double] = [:],
        world: [Joint: SIMD3<Double>] = [:]
    ) {
        self.points = points
        self.world = world
        self.timestamp = timestamp
        self.imageSize = imageSize
        self.confidence = confidence
    }

    public subscript(joint: Joint) -> CGPoint? {
        points[joint]
    }

    /// The same pose without its 3D points, so every measure reads the image.
    public var imageOnly: Pose {
        var copy = self
        copy.world = [:]
        return copy
    }

    /// The weakest confidence among `joints` that are in view. nil when the source gives none.
    public func confidence(of joints: [Joint]) -> Double? {
        joints.compactMap { points[$0] == nil ? nil : confidence[$0] }.min()
    }
}
