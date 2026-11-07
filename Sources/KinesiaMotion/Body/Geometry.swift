//
//  Geometry.swift
//  KinesiaMotion
//
//  Created by Deivy Mejia Ruiz on 4/10/26.
//

import CoreGraphics
import Foundation

/// Pure 2D math. Every result is in degrees.
enum Geometry {
    /// Inner angle at `vertex` between vertex→a and vertex→b. 0...180.
    static func angle(at vertex: CGPoint, _ a: CGPoint, _ b: CGPoint) -> Double? {
        let v1x = Double(a.x - vertex.x), v1y = Double(a.y - vertex.y)
        let v2x = Double(b.x - vertex.x), v2y = Double(b.y - vertex.y)
        let l1 = hypot(v1x, v1y), l2 = hypot(v2x, v2y)
        guard l1 > 0, l2 > 0 else { return nil }
        let cosine = max(-1, min(1, (v1x * v2x + v1y * v2y) / (l1 * l2)))
        return acos(cosine) * 180 / .pi
    }

    /// Angle between the segment from→to and straight down.
    /// 0 = pointing down, 90 = horizontal, 180 = pointing up.
    static func fromVertical(_ from: CGPoint, _ to: CGPoint) -> Double? {
        let dx = Double(to.x - from.x), dy = Double(to.y - from.y)
        let length = hypot(dx, dy)
        guard length > 0 else { return nil }
        return acos(max(-1, min(1, dy / length))) * 180 / .pi
    }

    /// How tilted a line is from level. 0 = level, 90 = vertical.
    static func tilt(_ a: CGPoint, _ b: CGPoint) -> Double? {
        let dx = abs(Double(b.x - a.x)), dy = abs(Double(b.y - a.y))
        guard dx + dy > 0 else { return nil }
        return atan2(dy, dx) * 180 / .pi
    }
}

/// The same measures in 3D: meters, y up. Every result is in degrees.
enum Geometry3D {
    /// Inner angle at `vertex` between vertex→a and vertex→b. 0...180.
    static func angle(at vertex: SIMD3<Double>, _ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double? {
        let v1 = a - vertex, v2 = b - vertex
        let l1 = length(v1), l2 = length(v2)
        guard l1 > 0, l2 > 0 else { return nil }
        let cosine = max(-1, min(1, dot(v1, v2) / (l1 * l2)))
        return acos(cosine) * 180 / .pi
    }

    /// Angle between the segment from→to and straight down (−y).
    /// 0 = pointing down, 90 = horizontal, 180 = pointing up.
    static func fromVertical(_ from: SIMD3<Double>, _ to: SIMD3<Double>) -> Double? {
        let d = to - from
        let l = length(d)
        guard l > 0 else { return nil }
        return acos(max(-1, min(1, -d.y / l))) * 180 / .pi
    }

    /// How tilted a line is from the horizontal plane. 0 = level, 90 = vertical.
    static func tilt(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double? {
        let d = b - a
        let horizontal = hypot(d.x, d.z)
        guard horizontal + abs(d.y) > 0 else { return nil }
        return atan2(abs(d.y), horizontal) * 180 / .pi
    }

    private static func dot(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double {
        (a * b).sum()
    }

    private static func length(_ v: SIMD3<Double>) -> Double {
        dot(v, v).squareRoot()
    }
}
