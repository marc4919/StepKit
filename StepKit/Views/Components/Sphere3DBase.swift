//
//  Sphere3DBase.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on 13/10/25.
//

import SwiftUI

/// Esfera 3D reutilizable con efecto de iluminación realista
struct Sphere3DBase: View {
    let size: CGFloat
    let animate: Bool
    
    private let sphereHighlight = Color(red: 0.55, green: 0.88, blue: 1.0)
    private let sphereBase = Color(red: 0.35, green: 0.75, blue: 1.0)
    private let sphereDark = Color(red: 0.25, green: 0.6, blue: 0.95)
    private let glowColor = Color(red: 0.2, green: 0.6, blue: 1.0)
    
    var body: some View {
        ZStack {
            // Capa base
            Circle()
                .fill(
                    RadialGradient(
                        colors: [sphereBase, sphereDark, Color(red: 0.0, green: 0.2, blue: 0.5)],
                        center: UnitPoint(x: 0.35, y: 0.3),
                        startRadius: 0,
                        endRadius: size * 0.625
                    )
                )
            
            // Iluminación principal
            Circle()
                .fill(
                    RadialGradient(
                        colors: [sphereHighlight.opacity(0.9), sphereBase.opacity(0.5), .clear],
                        center: UnitPoint(x: 0.25, y: 0.2),
                        startRadius: 0,
                        endRadius: size * 0.56
                    )
                )
            
            // Highlight especular
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.95), .white.opacity(0.4), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.15
                    )
                )
                .frame(width: size * 0.3, height: size * 0.3)
                .offset(x: -size * 0.22, y: -size * 0.25)
                .blur(radius: 1)
            
            // Segundo highlight
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.5), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.1
                    )
                )
                .frame(width: size * 0.2, height: size * 0.2)
                .offset(x: -size * 0.12, y: -size * 0.35)
                .blur(radius: 2)
            
            // Reflejo inferior
            Circle()
                .fill(
                    RadialGradient(
                        colors: [glowColor.opacity(0.3), .clear],
                        center: UnitPoint(x: 0.6, y: 0.85),
                        startRadius: 0,
                        endRadius: size * 0.375
                    )
                )
            
            // Borde
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.5), .white.opacity(0.1), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        }
        .frame(width: size, height: size)
        .shadow(color: sphereDark.opacity(0.6), radius: 20, x: 5, y: 10)
        .shadow(color: glowColor.opacity(0.3), radius: 8, x: -2, y: -2)
    }
}

#Preview {
    Sphere3DBase(size: 100, animate: true)
        .padding(50)
}

