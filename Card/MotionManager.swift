//
//  MotionManager.swift
//  Card
//
//  Publishes device tilt (roll & pitch) from CoreMotion
//  for use in parallax effects and gradient shifts.
//

import Foundation
import CoreMotion

class MotionManager: ObservableObject {
    @Published var roll: Double = 0.5
    @Published var pitch: Double = 0.5

    private var motionManager = CMMotionManager()

    init() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 1.0 / 30.0
        motionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { [weak self] motion, _ in
            guard let motion = motion else { return }
            // Map attitude to 0...1 range, centered at 0.5
            let roll = motion.attitude.roll   // left/right tilt (radians)
            let pitch = motion.attitude.pitch  // forward/backward tilt (radians)

            // Normalize: divide by π to get -1...1, then shift to 0...1
            self?.roll = max(0, min(1, (roll / .pi) + 0.5))
            self?.pitch = max(0, min(1, ((pitch - 0.5) / .pi) + 0.5))
        }
    }

    deinit {
        motionManager.stopDeviceMotionUpdates()
    }
}
