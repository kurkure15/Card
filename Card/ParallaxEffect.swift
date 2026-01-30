//
//  ParallaxEffect.swift
//  Card
//
//  Applies a subtle 3D tilt and offset to a view based on device motion.
//  Inspired by Any Distance's parallax card effect.
//

import SwiftUI

struct ParallaxEffect: ViewModifier {
    @StateObject private var manager = MotionManager()
    var magnitude: Double = 10.0

    func body(content: Content) -> some View {
        // Map 0...1 range to -1...1 centered
        let rollOffset = (manager.roll - 0.5) * 2.0
        let pitchOffset = (manager.pitch - 0.5) * 2.0

        content
            .rotation3DEffect(
                .degrees(rollOffset * magnitude),
                axis: (x: 0, y: 1, z: 0)
            )
            .rotation3DEffect(
                .degrees(pitchOffset * magnitude),
                axis: (x: 1, y: 0, z: 0)
            )
            .offset(
                x: rollOffset * magnitude * 0.5,
                y: pitchOffset * magnitude * 0.5
            )
    }
}

extension View {
    func parallaxEffect(magnitude: Double = 10.0) -> some View {
        self.modifier(ParallaxEffect(magnitude: magnitude))
    }

    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
