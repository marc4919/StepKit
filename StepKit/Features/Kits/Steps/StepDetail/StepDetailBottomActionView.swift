//
//  StepDetailBottomActionView.swift
//  StepKit
//
//  Created by Assistant on 2024-12-13.
//

import SwiftUI
import SwiftData

struct StepDetailBottomActionView: View {
    @Bindable var stepEntity: StepEntity
    @Binding var buttonScale: CGFloat
    @Binding var iconRotation: Double
    let onToggle: () -> Void
    
    var body: some View {
        Button {
            let wasCompleted = stepEntity.isCompleted

            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: wasCompleted ? .light : .medium)
            generator.impactOccurred()

            // Animación de rebote del botón
            withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                buttonScale = 0.92
                iconRotation += wasCompleted ? -360 : 360
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
                Image(systemName: stepEntity.isCompleted ? "arrow.uturn.backward.circle.fill" : "checkmark.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .rotationEffect(.degrees(iconRotation))

                Text(stepEntity.isCompleted ? String(localized: "Marcar como pendiente") : String(localized: "Marcar como completado"))
                    .font(.body)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                stepEntity.isCompleted
                    ? LinearGradient.pendingGradient
                    : LinearGradient.accentGradient
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("step.toggleCompletion")
        .accessibilityLabel(stepEntity.isCompleted ? String(localized: "Marcar como pendiente") : String(localized: "Marcar como completado"))
        .accessibilityValue(stepEntity.isCompleted ? String(localized: "Completado") : String(localized: "Pendiente"))
        .accessibilityHint("Toca dos veces para cambiar el estado de completado del paso")
        .scaleEffect(buttonScale)
        .animation(.easeInOut(duration: 0.2), value: stepEntity.isCompleted)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
        )
    }
}
