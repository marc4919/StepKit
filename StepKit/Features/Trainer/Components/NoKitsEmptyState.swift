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
        GeometryReader { geometry in
            VStack(spacing: 28) {
                Spacer()
                    .frame(maxHeight: 200)

                // Icono con estilo
                ZStack {
                    Circle()
                        .fill(LinearGradient.accentWithOpacity( 0.3))
                        .frame(width: 80, height: 80)

                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundStyle(LinearGradient.accentGradient)
                        .symbolEffect(.wiggle, options: .repeating)
                }

                // Textos
                VStack(spacing: 12) {
                    Text("Primero, crea tu kit")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                    Text("Para poder ayudarte con tu progreso, necesito que tengas al menos un kit activo.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()
                    .frame(maxHeight: 30)

                // Botón CTA
                Button {
                    onCreateKit()
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                        Text("Crear kit")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
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
                .opacity(showButton ? 1 : 0)
                .offset(y: showButton ? 0 : 20)

                Spacer()
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
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
