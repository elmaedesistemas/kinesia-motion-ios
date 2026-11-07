//
//  Vision3DLog.swift
//  KinesiaMotion
//
//  Created by Deivy Mejia Ruiz on 6/11/26.
//

import os
import KinesiaMotion

/// Tells the Xcode console why 3D points are or aren't arriving, once per change
/// (not every frame). Subsystem "one.kinesia.motion", category "vision3d".
enum Vision3DLog {
    private enum State: Equatable {
        case failed(String)
        case noBody
        case noPoints
        case working
    }

    private static let logger = Logger(subsystem: "one.kinesia.motion", category: "vision3d")
    private static let last = OSAllocatedUnfairLock<State?>(initialState: nil)

    /// Call after each frame that asked for 3D.
    static func report(error: Error?, bodies: Int, pose: Pose) {
        // Nobody in view isn't a 3D problem: keep the last state.
        if error == nil, pose.points.isEmpty { return }
        let state: State
        if let error {
            state = .failed(String(describing: error))
        } else if bodies == 0 {
            state = .noBody
        } else {
            state = pose.world.isEmpty ? .noPoints : .working
        }
        let changed = last.withLock { previous in
            defer { previous = state }
            return previous != state
        }
        guard changed else { return }

        switch state {
        case .failed(let message):
            logger.error("3D body pose failed: \(message, privacy: .public)")
        case .noBody:
            logger.warning("3D body pose found no body while 2D sees \(pose.points.count) joints")
        case .noPoints:
            logger.warning("3D body found, but no 3D joint matched a 2D joint")
        case .working:
            logger.info("3D points arriving: \(pose.world.count) joints")
        }
    }
}
