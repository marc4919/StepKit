//
//  AIConsentView.swift
//  StepKit
//
//  Created by Assistant on 2025-12-13.
//

import SwiftUI

/// Pantalla de consentimiento explícito para el uso de IA externa
/// Cumple con las normas de Apple de noviembre 2025 (Guideline 5.1.2(i))
struct AIConsentView: View {
    @State private var hasAccepted = false
    @State private var showingPrivacyPolicy = false
    @Environment(AIConsentManager.self) private var consentManager
    
    var onComplete: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: 24)
                    
                    // Icono y branding
                    iconSection
                    
                    Spacer()
                        .frame(height: 20)
                    
                    // Contenido principal
                    contentSection
                        .padding(.horizontal, 24)
                    
                    Spacer()
                        .frame(height: 20)
                    
                    // Checkbox de aceptación
                    consentCheckbox
                        .padding(.horizontal, 24)
                    
                    Spacer()
                        .frame(height: 24)
                    
                    // Botón de continuar
                    continueButton
                        .padding(.horizontal, 24)
                        .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? 16 : 32)
                }
            }
        }
        .background(
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color.accentColor.opacity(0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .sheet(isPresented: $showingPrivacyPolicy) {
            PrivacyPolicyView()
        }
    }
    
    // MARK: - Icon Section
    
    private var iconSection: some View {
        ZStack {
            // Glow exterior
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.accentHighlight.opacity(0.3), Color.accentColor.opacity(0.1), .clear],
                        center: .center,
                        startRadius: 15,
                        endRadius: 40
                    )
                )
                .frame(width: 70, height: 70)
            
            // Círculo de fondo
            Circle()
                .fill(LinearGradient.accentWithOpacity(0.2))
                .frame(width: 50, height: 50)
            
            // Icono de IA
            Image(systemName: "sparkles")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(LinearGradient.accentGradient)
                .symbolEffect(.breathe, options: .repeating, isActive: true)
        }
    }
    
    // MARK: - Content Section
    
    private var contentSection: some View {
        VStack(spacing: 24) {
            // Título
            Text("Uso de Inteligencia Artificial")
                .font(.title2)
                .bold()
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
            
            // Descripción principal
            VStack(alignment: .leading, spacing: 16) {
                Text("Para generar planes personalizados, StepKit utiliza servicios de inteligencia artificial externos.")
                    .font(.body)
                    .foregroundStyle(.primary)
                
                Text("Datos que compartimos:")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .padding(.top, 8)
                
                VStack(alignment: .leading, spacing: 12) {
                    dataPoint(
                        icon: "target",
                        text: "Objetivos personales"
                    )
                    
                    dataPoint(
                        icon: "calendar",
                        text: "Fechas y disponibilidad de tiempo"
                    )
                    
                    dataPoint(
                        icon: "exclamationmark.triangle",
                        text: "Obstáculos que mencionas"
                    )
                }
                .padding(.leading, 8)
                
                Text("Estos datos se procesan mediante servicios de IA de terceros a través de nuestro servidor seguro para generar planes personalizados. No compartimos tu información con fines publicitarios ni la vendemos a terceros.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }
            .padding(20)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
    
    private func dataPoint(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)
            
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
    }
    
    // MARK: - Consent Checkbox
    
    private var consentCheckbox: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                hasAccepted.toggle()
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(hasAccepted ? AnyShapeStyle(LinearGradient.accentGradient) : AnyShapeStyle(Color(.systemGray5)))
                        .frame(width: 24, height: 24)
                    
                    if hasAccepted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Acepto compartir mis datos con servicios de IA externos")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    
                    HStack(spacing: 4) {
                        Text("He leído y acepto la")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Button {
                            showingPrivacyPolicy = true
                        } label: {
                            Text("Política de Privacidad")
                                .font(.caption)
                                .foregroundStyle(Color.accentColor)
                        }
                        .accessibilityAddTraits(.isButton)
                    }
                }
                
                Spacer()
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isButton)
    }
    
    // MARK: - Continue Button
    
    private var continueButton: some View {
        Button {
            consentManager.giveConsent()
            onComplete()
        } label: {
            HStack(spacing: 8) {
                Text("Continuar")
                    .font(.headline)
                
                Image(systemName: "arrow.right")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(hasAccepted ? .white : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Capsule()
                    .fill(hasAccepted ? LinearGradient.accentGradient : LinearGradient.disabledGradient)
            )
            .overlay(
                Capsule()
                    .stroke(hasAccepted ? Color.white.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .glowShadow(opacity: hasAccepted ? 0.4 : 0, radius: hasAccepted ? 12 : 0, y: hasAccepted ? 6 : 0)
        }
        .disabled(!hasAccepted)
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    AIConsentView(onComplete: {})
        .environment(AIConsentManager())
}

#Preview("Dark Mode") {
    AIConsentView(onComplete: {})
        .preferredColorScheme(.dark)
        .environment(AIConsentManager())
}

