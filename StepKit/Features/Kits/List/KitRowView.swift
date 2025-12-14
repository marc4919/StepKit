//
//  KitRowView.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on 13/10/25.
//
//  Refactored by StepKit Refactor.
//

import SwiftUI
import SwiftData

/// Celda de un objetivo/kit en la lista
struct KitRowView: View {
    let kitEntity: GoalEntity


    // Usar la propiedad STORED 'progress' en lugar de computedProgress para que SwiftUI detecte cambios
    // La propiedad 'progress' se actualiza en StepDetailView.toggleStepCompletion()
    private var progress: Double {
        kitEntity.progress
    }

    // Usar steps directamente para forzar observación de la relación
    private var isCompleted: Bool {
        !kitEntity.steps.isEmpty && kitEntity.steps.allSatisfy { $0.isCompleted }
    }

    private var dueDate: Date? {
        kitEntity.steps.compactMap { $0.suggestedDeadline }.max()
    }

    var body: some View {
        HStack(spacing: 14) {
            // Indicador de progreso circular
            progressIndicator

            // Contenido principal
            VStack(alignment: .leading, spacing: 6) {
                Text(kitEntity.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(2)

                Text(kitEntity.kpi)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                // Fecha objetivo
                if let dueDate = dueDate, !isCompleted {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                        Text(dueDate, format: .dateTime.day().month(.abbreviated))
                            .font(.caption)
                    }
                    .foregroundColor(isDueSoon ? .orange : .secondary)
                }
            }

            Spacer()
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    isCompleted
                        ? Color.green.opacity(0.3)
                        : Color.clear,
                    lineWidth: 1.5
                )
        )
    }

    // MARK: - Progress Indicator
    private var progressIndicator: some View {
        ZStack {
            // Fondo del círculo
            Circle()
                .stroke(Color.accentColor.opacity(0.15), lineWidth: 4)
                .frame(width: 48, height: 48)

            // Progreso
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    isCompleted
                        ? LinearGradient.completedGradient
                        : LinearGradient.accentGradient,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .frame(width: 48, height: 48)
                .rotationEffect(.degrees(-90))

            // Contenido central
            if isCompleted {
                Image(systemName: "checkmark")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.green)
            } else {
                Text("\(Int(progress * 100))")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.accentColor)
            }
        }
    }

    // MARK: - Helpers
    private var isDueSoon: Bool {
        guard let dueDate = dueDate else { return false }
        let daysRemaining = Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
        return daysRemaining <= 3 && daysRemaining >= 0
    }
}

#Preview("En progreso") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: GoalEntity.self, StepEntity.self, configurations: config)
    let kitEntity = GoalEntity(
        planTitle: "Aprender SwiftUI",
        horizonDays: 42,
        kpi: "Completar 5 proyectos funcionales"
    )
    container.mainContext.insert(kitEntity)

    return KitRowView(kitEntity: kitEntity)
        .padding()
        .background(Color(.systemGroupedBackground))
        .modelContainer(container)
}

#Preview("Completado") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: GoalEntity.self, StepEntity.self, configurations: config)
    let kitEntity = GoalEntity(
        planTitle: "Configurar proyecto",
        horizonDays: 7,
        kpi: "Proyecto funcionando",
        progress: 1.0
    )
    container.mainContext.insert(kitEntity)

    return KitRowView(kitEntity: kitEntity)
        .padding()
        .background(Color(.systemGroupedBackground))
        .modelContainer(container)
}
