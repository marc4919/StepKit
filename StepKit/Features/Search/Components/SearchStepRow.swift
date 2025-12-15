//
//  SearchStepRow.swift
//  StepKit
//
//  Created by StepKit Refactor.
//

import SwiftUI

struct SearchStepRow: View {
    let step: Step
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                // Icono circular
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.1))
                        .frame(width: 44, height: 44)

                    Image(systemName: "list.bullet")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
                .accessibilityHidden(true)

                // Contenido
                VStack(alignment: .leading, spacing: 4) {
                    Text(step.stepTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Text(step.description.short)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    // Tiempo estimado
                    if step.estimateMinutes > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption2)
                                .accessibilityHidden(true)
                            Text(step.estimateMinutes.formattedDuration())
                                .font(.caption)
                        }
                        .foregroundStyle(.tertiary)
                        .padding(.top, 2)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color(.tertiaryLabel))
                    .accessibilityHidden(true)
            }
            .appCardStyle(backgroundColor: Color(.secondarySystemGroupedBackground))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Paso: \(step.stepTitle)")
        .accessibilityValue(step.estimateMinutes > 0 ? "Tiempo estimado: \(step.estimateMinutes.formattedDuration())" : "")
        .accessibilityHint("Toca dos veces para abrir los detalles del paso")
    }
}
