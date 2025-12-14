//
//  KitCreationLoadingView.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on 1/12/25.
//

import SwiftUI

/// Vista de carga mientras se crea el kit con la API
struct KitCreationLoadingView: View {
    // Mensajes que van rotando
    private let loadingTips = [
        "Analizando tu objetivo...",
        "Creando pasos personalizados...",
        "Optimizando el plan...",
        "Casi listo..."
    ]
    
    var body: some View {
        ZStack {
            // Fondo
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Animación central
                LoadingSpinner()
                    .frame(width: 200, height: 200)
                
                // Texto de carga
                LoadingText(tips: loadingTips)
                
                Spacer()
                Spacer()
            }
        }
    }
}

// MARK: - Loading Spinner (Subview separada para aislar animaciones)
private struct LoadingSpinner: View {
    @State private var rotation: Double = 0
    @State private var pulseScale: CGFloat = 0.9
    @State private var glowOpacity: Double = 0.3

    var body: some View {
        ZStack {
            // Glow exterior
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.glowColor.opacity(glowOpacity), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 100
                    )
                )
                .frame(width: 200, height: 200)
                .blur(radius: 20)

            // Anillo exterior rotando
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [Color.accentHighlight, Color.accentColor, Color.accentHighlight.opacity(0.3), .clear],
                        center: .center
                    ),
                    lineWidth: 4
                )
                .frame(width: 120, height: 120)
                .rotationEffect(.degrees(rotation))

            // Anillo medio
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [Color.accentColor.opacity(0.6), Color.accentHighlight.opacity(0.4), .clear],
                        center: .center
                    ),
                    lineWidth: 3
                )
                .frame(width: 90, height: 90)
                .rotationEffect(.degrees(-rotation * 0.7))

            // Círculo central pulsante
            Circle()
                .fill(LinearGradient.accentGradient)
                .frame(width: 50, height: 50)
                .scaleEffect(pulseScale)
                .shadow(color: Color.accentColor.opacity(0.5), radius: 15, x: 0, y: 5)

            // Icono central
            Image(systemName: "sparkles")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.white)
                .scaleEffect(pulseScale)
        }
        .onAppear {
            // Rotación - animación muy larga para evitar reinicios
            withAnimation(.linear(duration: 60).repeatForever(autoreverses: false)) {
                rotation = 21600 // 60 vueltas en 60 segundos = 1 vuelta/segundo
            }
            
            // Pulso
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulseScale = 1.1
            }
            
            // Glow
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                glowOpacity = 0.6
            }
        }
    }
}

// MARK: - Loading Text (Subview separada para aislar el timer)
private struct LoadingText: View {
    let tips: [String]
    
    @State private var currentTipIndex = 0
    @State private var timer: Timer?
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Creando tu kit")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
            
            Text(tips[currentTipIndex])
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .animation(.easeInOut(duration: 0.3), value: currentTipIndex)
        }
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { _ in
            withAnimation {
                currentTipIndex = (currentTipIndex + 1) % tips.count
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

#Preview {
    KitCreationLoadingView()
}
