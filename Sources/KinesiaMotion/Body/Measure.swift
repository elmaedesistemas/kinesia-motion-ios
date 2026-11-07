//
//  Measure.swift
//  KinesiaMotion
//
//  Created by Deivy Mejia Ruiz on 4/10/26.
//

import CoreGraphics

/// Where a measure is taken.
public enum MeasureSpace: String, Sendable, CaseIterable {
    /// On the camera image (2D). Needs the patient square to the camera.
    case image
    /// With the pose's 3D points. Holds even when the patient turns a little.
    case world
}

/// Something we can read from a pose, in degrees. Pure data: it can live in JSON.
public enum Measure: Sendable, Hashable, Codable {
    /// Inner angle at `vertex` (0...180).
    case angle(a: LandmarkRef, vertex: LandmarkRef, b: LandmarkRef)
    /// 180 − inner angle: 0 = straight limb, grows as it bends.
    case flexion(a: LandmarkRef, vertex: LandmarkRef, b: LandmarkRef)
    /// Segment from→to against straight down (0 down, 90 horizontal, 180 up).
    case fromVertical(from: LandmarkRef, to: LandmarkRef)
    /// Line between two landmarks against level (0 level, 90 vertical).
    case tilt(a: LandmarkRef, b: LandmarkRef)

    /// The measure in 3D when the pose has world points for every joint it needs,
    /// otherwise in the image.
    public func value(in pose: Pose, side: BodySide) -> Double? {
        worldValue(in: pose, side: side) ?? imageValue(in: pose, side: side)
    }

    /// The measure in one space only, with no fallback to the other.
    public func value(in pose: Pose, side: BodySide, space: MeasureSpace) -> Double? {
        switch space {
        case .image: imageValue(in: pose, side: side)
        case .world: worldValue(in: pose, side: side)
        }
    }

    /// `space` nil: 3D when available, image otherwise. Otherwise that space only.
    func value(in pose: Pose, side: BodySide, preferring space: MeasureSpace?) -> Double? {
        guard let space else { return value(in: pose, side: side) }
        return value(in: pose, side: side, space: space)
    }

    /// The measure in the image plane, ignoring any 3D points.
    public func imageValue(in pose: Pose, side: BodySide) -> Double? {
        func point(_ ref: LandmarkRef) -> CGPoint? { pose[ref.joint(for: side)] }

        switch self {
        case let .angle(a, vertex, b):
            guard let pa = point(a), let pv = point(vertex), let pb = point(b) else { return nil }
            return Geometry.angle(at: pv, pa, pb)

        case let .flexion(a, vertex, b):
            return Measure.angle(a: a, vertex: vertex, b: b)
                .imageValue(in: pose, side: side)
                .map { 180 - $0 }

        case let .fromVertical(from, to):
            guard let pf = point(from), let pt = point(to) else { return nil }
            return Geometry.fromVertical(pf, pt)

        case let .tilt(a, b):
            guard let pa = point(a), let pb = point(b) else { return nil }
            return Geometry.tilt(pa, pb)
        }
    }

    /// The measure in 3D. nil when any joint it needs has no world point.
    public func worldValue(in pose: Pose, side: BodySide) -> Double? {
        func point(_ ref: LandmarkRef) -> SIMD3<Double>? { pose.world[ref.joint(for: side)] }

        switch self {
        case let .angle(a, vertex, b):
            guard let pa = point(a), let pv = point(vertex), let pb = point(b) else { return nil }
            return Geometry3D.angle(at: pv, pa, pb)

        case let .flexion(a, vertex, b):
            return Measure.angle(a: a, vertex: vertex, b: b)
                .worldValue(in: pose, side: side)
                .map { 180 - $0 }

        case let .fromVertical(from, to):
            guard let pf = point(from), let pt = point(to) else { return nil }
            return Geometry3D.fromVertical(pf, pt)

        case let .tilt(a, b):
            guard let pa = point(a), let pb = point(b) else { return nil }
            return Geometry3D.tilt(pa, pb)
        }
    }

    /// The joints this measure needs to see. Used for "show your whole arm" guidance.
    public func joints(for side: BodySide) -> [Joint] {
        let refs: [LandmarkRef]
        switch self {
        case let .angle(a, vertex, b), let .flexion(a, vertex, b): refs = [a, vertex, b]
        case let .fromVertical(from, to): refs = [from, to]
        case let .tilt(a, b): refs = [a, b]
        }
        return refs.map { $0.joint(for: side) }
    }
}
