//
//  NoKitsEmptyState.swift
//  StepKit
//
//  Extracted from TrainerView.swift
//

import SwiftUI

struct NoKitsEmptyState: View {
    let onCreateKit: () -> Void
    @State private var showButton = false
    
    var body: some View {
        VStack(spacing: 28) {
            Spacer()
                .frame(maxHeight: 200)

            // Icono con estilo (decorativo, la información está en los textos)
            ZStack {
                Circle()
                    .fill(LinearGradient.accentWithOpacity( 0.3))
                    .frame(width: 80, height: 80)
                    .accessibilityHidden(true)

                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(LinearGradient.accentGradient)
                    .symbolEffect(.wiggle, options: .repeating)
                    .accessibilityHidden(true)
            }

            // Textos
            VStack(spacing: 12) {
                Text("Primero, crea tu kit")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

                Text("Para poder ayudarte con tu progreso, necesito que tengas al menos un kit activo.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Primero, crea tu kit. Para poder ayudarte con tu progreso, necesito que tengas al menos un kit activo.")

            Spacer()
                .frame(maxHeight: 30)

            // Botón CTA
            Button {
                onCreateKit()
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .accessibilityHidden(true)
                    Text("Crear kit")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(LinearGradient.accentGradient)
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
                .glowShadow()
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("Crear kit")
            .accessibilityHint("Toca dos veces para crear tu primer kit")
            .opacity(showButton ? 1 : 0)
            .offset(y: showButton ? 0 : 20)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .contentShape(Rectangle())
        .onTapGesture {
            onCreateKit()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(0.3)) {
                showButton = true
            }
        }
        .onDisappear {
            showButton = false
        }
    }
}
