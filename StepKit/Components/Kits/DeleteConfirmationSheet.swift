//
//  DeleteConfirmationSheet.swift
//  StepKit
//
//  Created by StepKit Refactor.
//

import SwiftUI

struct DeleteConfirmationSheet: View {
    let goal: GoalEntity?
    let onDelete: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Icono
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.1))
                    .frame(width: 72, height: 72)

                Image(systemName: "trash")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(.red)
            }
            .padding(.top, 24)

            // Texto
            VStack(spacing: 8) {
                Text("¿Eliminar este kit?")
                    .font(.title3)
                    .fontWeight(.semibold)

                if let goal = goal {
                    Text(goal.title)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }

                Text("Esta acción no se puede deshacer")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }

            // Botones
            VStack(spacing: 12) {
                Button(role: .destructive, action: onDelete) {
                    Text("Eliminar")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                Button(action: onCancel) {
                    Text("Cancelar")
                        .font(.body.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(.secondarySystemGroupedBackground))
                        .foregroundColor(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .presentationDetents([.height(340)])
        .presentationDragIndicator(.visible)
    }
}
