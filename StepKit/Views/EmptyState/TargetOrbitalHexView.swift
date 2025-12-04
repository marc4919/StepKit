//
//  TargetOrbitalHexView.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on 13/10/25.
//

import SwiftUI

/// Animación principal del estado vacío: ondas que se expanden desde el centro + esfera 3D con Liquid Glass
struct TargetOrbitalHexView: View {
    let animate: Bool
    var size: CGFloat = 240 // Tamaño configurable, por defecto 240
    
    private let glowColor = Color(red: 0.2, green: 0.6, blue: 1.0)
    private let cycleDuration: Double = 10.0 // Duración de un ciclo completo (más lento = más fluido)
    
    @State private var glowScale: CGFloat = 0.9
    @State private var startDate: Date = Date()
    
    // Factor de escala basado en el tamaño
    private var scale: CGFloat { size / 240 }
    
    // Interpolación sinusoidal para movimiento orgánico (ease-in-out)
    private func easeInOut(_ t: CGFloat) -> CGFloat {
        // Curva sinusoidal: empieza lento, acelera en el medio, termina lento
        return (1 - cos(t * .pi)) / 2
    }
    
    // Calcula la fase de un círculo con offset (0 a 1, se repite)
    private func circlePhase(for date: Date, offset: Double) -> CGFloat {
        let elapsed = date.timeIntervalSince(startDate)
        let linearPhase = (elapsed / cycleDuration + offset).truncatingRemainder(dividingBy: 1.0)
        // Aplicar easing sinusoidal para suavizar
        return easeInOut(CGFloat(linearPhase))
    }
    
    // Calcula el tamaño de un círculo basándose en su fase (se expande desde el centro)
    private func circleSize(phase: CGFloat) -> CGFloat {
        let minSize: CGFloat = 50 // Empieza cerca de la esfera
        let maxSize: CGFloat = 200 // Se expande hasta el borde
        return (minSize + (maxSize - minSize) * phase) * scale
    }
    
    // Calcula la opacidad de un círculo basándose en su fase
    // Aparece en el centro, se desvanece al expandirse
    private func circleOpacity(baseOpacity: Double, phase: CGFloat) -> Double {
        let fadeInEnd: CGFloat = 0.1
        let fadeOutStart: CGFloat = 0.6
        
        let visibilityMultiplier: CGFloat
        if phase < fadeInEnd {
            // Fade-in: aparece rápido desde el centro
            visibilityMultiplier = phase / fadeInEnd
        } else if phase > fadeOutStart {
            // Fade-out: se desvanece mientras se expande
            visibilityMultiplier = (1 - phase) / (1 - fadeOutStart)
        } else {
            // Totalmente visible en el medio
            visibilityMultiplier = 1
        }
        
        return baseOpacity * Double(visibilityMultiplier)
    }
    
    var body: some View {
        TimelineView(.animation) { timeline in
            let wave1Phase = circlePhase(for: timeline.date, offset: 0)
            let wave2Phase = circlePhase(for: timeline.date, offset: 0.33)
            let wave3Phase = circlePhase(for: timeline.date, offset: 0.66)
            
            ZStack {
                // === CONTENIDO ANIMADO ===
                ZStack {
                    // === ONDAS QUE SE EXPANDEN ===
                    // Onda 1
                    Circle()
                        .stroke(glowColor.opacity(circleOpacity(baseOpacity: 0.3, phase: wave1Phase)), lineWidth: 2.5)
                        .frame(width: circleSize(phase: wave1Phase), height: circleSize(phase: wave1Phase))
                    
                    // Onda 2 (desfasada 1/3)
                    Circle()
                        .stroke(glowColor.opacity(circleOpacity(baseOpacity: 0.3, phase: wave2Phase)), lineWidth: 2.5)
                        .frame(width: circleSize(phase: wave2Phase), height: circleSize(phase: wave2Phase))
                    
                    // Onda 3 (desfasada 2/3)
                    Circle()
                        .stroke(glowColor.opacity(circleOpacity(baseOpacity: 0.3, phase: wave3Phase)), lineWidth: 2.5)
                        .frame(width: circleSize(phase: wave3Phase), height: circleSize(phase: wave3Phase))
                    
                    // === GLOW CENTRAL ===
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [glowColor.opacity(0.5), glowColor.opacity(0.2), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 40 * scale
                            )
                        )
                        .frame(width: 80 * scale, height: 80 * scale)
                        .scaleEffect(glowScale)
                        .opacity(glowScale > 1.0 ? 0.8 : 0.5)
                        .blur(radius: 10 * scale)
                    
                    // === ESFERA 3D CENTRAL ===
                    Sphere3DBase(size: 40 * scale, animate: animate)
                }
                .padding(30 * scale)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 32 * scale, style: .continuous))
        .glassEffect(in: RoundedRectangle(cornerRadius: 32 * scale, style: .continuous))
        .onAppear {
            startAnimations()
        }
        .onChange(of: animate) { _, newValue in
            if newValue {
                startDate = Date()
                startAnimations()
            }
        }
    }
    
    private func startAnimations() {
        // Glow
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            glowScale = 1.15
        }
    }
}

#Preview("Normal (240)") {
    TargetOrbitalHexView(animate: true, size: 240)
}

#Preview("Compact (140)") {
    TargetOrbitalHexView(animate: true, size: 140)
}

