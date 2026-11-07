//
//  WorldSideTests.swift
//  KinesiaMotion
//
//  Created by Deivy Mejia Ruiz on 6/11/26.
//

import CoreGraphics
import Testing
import KinesiaMotion
@testable import KinesiaMotionVision

/// A 3D joint goes to the 2D joint it sits on in the image, whatever side its name says.
@Suite("3D joint sides")
struct WorldSideTests {
    private let size = CGSize(width: 480, height: 640)

    @Test func keepsTheNamedSideWhenItSitsThere() {
        let points: [KinesiaMotion.Joint: CGPoint] = [.rightElbow: CGPoint(x: 300, y: 300), .leftElbow: CGPoint(x: 150, y: 300)]
        #expect(Pose.side(for: .rightElbow, at: CGPoint(x: 302, y: 298), in: points, imageSize: size) == .rightElbow)
    }

    @Test func swapsWhenTheNameIsOnTheOtherSide() {
        // Side view: only one arm in 2D. A 3D model that names it the other way still lands on it.
        let points: [KinesiaMotion.Joint: CGPoint] = [.rightElbow: CGPoint(x: 300, y: 300)]
        #expect(Pose.side(for: .leftElbow, at: CGPoint(x: 305, y: 296), in: points, imageSize: size) == .rightElbow)
    }

    @Test func dropsAJointFarFromAnyMatch() {
        let points: [KinesiaMotion.Joint: CGPoint] = [.rightElbow: CGPoint(x: 300, y: 300)]
        #expect(Pose.side(for: .rightElbow, at: CGPoint(x: 20, y: 620), in: points, imageSize: size) == nil)
    }

    @Test func midlineJointsMatchThemselves() {
        let points: [KinesiaMotion.Joint: CGPoint] = [.neck: CGPoint(x: 240, y: 200)]
        #expect(Pose.side(for: .neck, at: CGPoint(x: 245, y: 205), in: points, imageSize: size) == .neck)
    }

    @Test func withoutAnImagePositionTheNameDecides() {
        let points: [KinesiaMotion.Joint: CGPoint] = [.rightElbow: CGPoint(x: 300, y: 300)]
        #expect(Pose.side(for: .rightElbow, at: nil, in: points, imageSize: size) == .rightElbow)
        #expect(Pose.side(for: .leftElbow, at: nil, in: points, imageSize: size) == nil)
    }
}
