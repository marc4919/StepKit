//
//  ShadowStyle.swift
//  StepKit
//
//  Centralized shadow modifiers for the app.
//  Provides consistent glow and shadow effects across views.
//

import SwiftUI

// MARK: - Glow Shadow Modifier

/// A view modifier that applies a glow shadow effect using the app's glow color
struct GlowShadow: ViewModifier {
    var opacity: Double
    var radius: CGFloat
    var x: CGFloat
    var y: CGFloat

    init(opacity: Double = 0.4, radius: CGFloat = 12, x: CGFloat = 0, y: CGFloat = 6) {
        self.opacity = opacity
        self.radius = radius
        self.x = x
        self.y = y
    }

    func body(content: Content) -> some View {
        content.shadow(
            color: .glowColor.opacity(opacity),
            radius: radius,
            x: x,
            y: y
        )
    }
}

// MARK: - Accent Shadow Modifier

/// A view modifier that applies an accent-colored shadow
struct AccentShadow: ViewModifier {
    var opacity: Double
    var radius: CGFloat
    var x: CGFloat
    var y: CGFloat

    init(opacity: Double = 0.3, radius: CGFloat = 8, x: CGFloat = 0, y: CGFloat = 4) {
        self.opacity = opacity
        self.radius = radius
        self.x = x
        self.y = y
    }

    func body(content: Content) -> some View {
        content.shadow(
            color: Color.accentColor.opacity(opacity),
            radius: radius,
            x: x,
            y: y
        )
    }
}

// MARK: - Soft Shadow Modifier

/// A view modifier that applies a subtle soft shadow
struct SoftShadow: ViewModifier {
    var opacity: Double
    var radius: CGFloat
    var y: CGFloat

    init(opacity: Double = 0.05, radius: CGFloat = 1, y: CGFloat = 1) {
        self.opacity = opacity
        self.radius = radius
        self.y = y
    }

    func body(content: Content) -> some View {
        content.shadow(
            color: .black.opacity(opacity),
            radius: radius,
            x: 0,
            y: y
        )
    }
}

// MARK: - View Extensions

extension View {
    /// Applies a glow shadow using the app's glow color
    /// - Parameters:
    ///   - opacity: Shadow opacity (default: 0.4)
    ///   - radius: Shadow blur radius (default: 12)
    ///   - x: Horizontal offset (default: 0)
    ///   - y: Vertical offset (default: 6)
    func glowShadow(
        opacity: Double = 0.4,
        radius: CGFloat = 12,
        x: CGFloat = 0,
        y: CGFloat = 6
    ) -> some View {
        modifier(GlowShadow(opacity: opacity, radius: radius, x: x, y: y))
    }

    /// Applies an accent-colored shadow
    /// - Parameters:
    ///   - opacity: Shadow opacity (default: 0.3)
    ///   - radius: Shadow blur radius (default: 8)
    ///   - x: Horizontal offset (default: 0)
    ///   - y: Vertical offset (default: 4)
    func accentShadow(
        opacity: Double = 0.3,
        radius: CGFloat = 8,
        x: CGFloat = 0,
        y: CGFloat = 4
    ) -> some View {
        modifier(AccentShadow(opacity: opacity, radius: radius, x: x, y: y))
    }

    /// Applies a subtle soft shadow
    /// - Parameters:
    ///   - opacity: Shadow opacity (default: 0.05)
    ///   - radius: Shadow blur radius (default: 1)
    ///   - y: Vertical offset (default: 1)
    func softShadow(
        opacity: Double = 0.05,
        radius: CGFloat = 1,
        y: CGFloat = 1
    ) -> some View {
        modifier(SoftShadow(opacity: opacity, radius: radius, y: y))
    }
}
