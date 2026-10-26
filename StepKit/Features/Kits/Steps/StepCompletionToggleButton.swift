//
//  StepCompletionToggleButton.swift
//  StepKit
//
//  Extracted from StepDetailView.swift
//

import SwiftUI

struct StepCompletionToggleButton: View {
    let isCompleted: Bool
    let onToggle: () -> Void
    
    @State private var buttonScale: CGFloat = 1.0
    @State private var iconRotation: Double = 0
    
    var body: some View {
        Button {
            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: isCompleted ? .light : .medium)
            generator.impactOccurred()

            // Animación de rebote del botón
            withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                buttonScale = 0.92
                iconRotation += isCompleted ? -360 : 360
            }

            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(100))
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    buttonScale = 1.0
                }
            }

            onToggle()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isCompleted ? "arrow.uturn.backward.circle.fill" : "checkmark.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .rotationEffect(.degrees(iconRotation))

                Text(isCompleted ? String(localized: "Marcar como pendiente") : String(localized: "Marcar como completado"))
                    .font(.body)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                isCompleted
                    ? LinearGradient.pendingGradient
                    : LinearGradient.accentGradient
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .scaleEffect(buttonScale)
        .animation(.easeInOut(duration: 0.2), value: isCompleted)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
        )
    }
}
