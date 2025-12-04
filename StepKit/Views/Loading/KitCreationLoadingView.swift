//
//  KitCreationLoadingView.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on 1/12/25.
//

import SwiftUI

/// Vista de carga mientras se crea el kit con la API
struct KitCreationLoadingView: View {
    // Colores del tema
    private let accentBlue = Color(red: 0.0, green: 0.48, blue: 1.0)
    private let accentHighlight = Color(red: 0.55, green: 0.82, blue: 1.0)
    private let glowColor = Color(red: 0.2, green: 0.6, blue: 1.0)
    
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
                LoadingSpinner(
                    accentBlue: accentBlue,
                    accentHighlight: accentHighlight,
                    glowColor: glowColor
                )
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
    let accentBlue: Color
    let accentHighlight: Color
    let glowColor: Color
    
    @State private var rotation: Double = 0
    @State private var pulseScale: CGFloat = 0.9
    @State private var glowOpacity: Double = 0.3
    
    var body: some View {
        ZStack {
            // Glow exterior
            Circle()
                .fill(
                    RadialGradient(
                        colors: [glowColor.opacity(glowOpacity), .clear],
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
                        colors: [accentHighlight, accentBlue, accentHighlight.opacity(0.3), .clear],
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
                        colors: [accentBlue.opacity(0.6), accentHighlight.opacity(0.4), .clear],
                        center: .center
                    ),
                    lineWidth: 3
                )
                .frame(width: 90, height: 90)
                .rotationEffect(.degrees(-rotation * 0.7))
            
            // Círculo central pulsante
            Circle()
                .fill(
                    LinearGradient(
                        colors: [accentHighlight, accentBlue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 50, height: 50)
                .scaleEffect(pulseScale)
                .shadow(color: accentBlue.opacity(0.5), radius: 15, x: 0, y: 5)
            
            // Icono central
            Image(systemName: "sparkles")
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(.white)
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
                .foregroundColor(.primary)
            
            Text(tips[currentTipIndex])
                .font(.subheadline)
                .foregroundColor(.secondary)
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
