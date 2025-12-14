//
//  Gradient+App.swift
//  StepKit
//
//  Centralized gradient definitions for the app.
//  Reduces duplication of LinearGradient patterns across views.
//

import SwiftUI

// MARK: - LinearGradient Extensions

extension LinearGradient {
    // MARK: - Primary Theme Gradients

    /// Primary accent gradient (accentHighlight → accentColor)
    /// Used for buttons, progress indicators, and interactive elements
    static let accentGradient = LinearGradient(
        colors: [Color.accentHighlight, Color.accentColor],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Creates an accent gradient with custom opacity
    /// - Parameter opacity: The opacity value (0.0 to 1.0)
    /// - Returns: A LinearGradient with the specified opacity
    static func accentWithOpacity(_ opacity: Double) -> LinearGradient {
        LinearGradient(
            colors: [
                Color.accentHighlight.opacity(opacity),
                Color.accentColor.opacity(opacity * 0.7)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Status Gradients

    /// Completed state gradient (green tones)
    /// Used for completed kits and steps
    static let completedGradient = LinearGradient(
        colors: [Color.green, Color.green.opacity(0.8)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Creates a completed gradient with custom opacity
    static func completedWithOpacity(_ opacity: Double) -> LinearGradient {
        LinearGradient(
            colors: [
                Color.green.opacity(opacity),
                Color.green.opacity(opacity * 0.8)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Premium Gradients

    /// Premium feature gradient (gold → orange)
    /// Used for premium badges and locked features
    static let premiumGradient = LinearGradient(
        colors: [Color.premiumGold, Color.premiumOrange],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Creates a premium gradient with custom opacity
    static func premiumWithOpacity(_ opacity: Double) -> LinearGradient {
        LinearGradient(
            colors: [
                Color.premiumGold.opacity(opacity),
                Color.premiumOrange.opacity(opacity)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Warning/Error Gradients

    /// Warning gradient (orange → red)
    /// Used for warnings and error states
    static let warningGradient = LinearGradient(
        colors: [Color.orange, Color.red.opacity(0.8)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Subtle warning background gradient
    static func warningWithOpacity(_ opacity: Double) -> LinearGradient {
        LinearGradient(
            colors: [
                Color.orange.opacity(opacity),
                Color.red.opacity(opacity * 0.5)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Disabled State

    /// Disabled/inactive gradient (gray tones)
    static let disabledGradient = LinearGradient(
        colors: [Color(UIColor.systemGray5), Color(UIColor.systemGray5)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - RadialGradient Extensions

extension RadialGradient {
    /// Sphere highlight radial gradient for 3D effects
    static let sphere3DHighlight = RadialGradient(
        colors: [
            Color.sphereHighlight.opacity(0.9),
            Color.sphereBase.opacity(0.6),
            Color.sphereDark.opacity(0.3)
        ],
        center: .topLeading,
        startRadius: 0,
        endRadius: 100
    )

    /// Glow effect radial gradient
    static func glow(radius: CGFloat = 50) -> RadialGradient {
        RadialGradient(
            colors: [
                Color.glowColor.opacity(0.6),
                Color.glowColor.opacity(0.0)
            ],
            center: .center,
            startRadius: 0,
            endRadius: radius
        )
    }
}
