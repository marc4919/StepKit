//
//  GoalRowView.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on 13/10/25.
//

import SwiftUI
import SwiftData

/// Celda de un objetivo/kit en la lista
struct GoalRowView: View {
    let goalEntity: GoalEntity

    // Colores del tema
    private let accentBlue = Color(red: 0.0, green: 0.48, blue: 1.0)
    private let accentHighlight = Color(red: 0.55, green: 0.82, blue: 1.0)
    private let glowColor = Color(red: 0.2, green: 0.6, blue: 1.0)

    // Usar la propiedad STORED 'progress' en lugar de computedProgress para que SwiftUI detecte cambios
    // La propiedad 'progress' se actualiza en StepDetailView.toggleStepCompletion()
    private var progress: Double {
        goalEntity.progress
    }

    // Usar steps directamente para forzar observación de la relación
    private var isCompleted: Bool {
        !goalEntity.steps.isEmpty && goalEntity.steps.allSatisfy { $0.isCompleted }
    }

    private var dueDate: Date? {
        goalEntity.steps.compactMap { $0.suggestedDeadline }.max()
    }

    var body: some View {
        HStack(spacing: 14) {
            // Indicador de progreso circular
            progressIndicator

            // Contenido principal
            VStack(alignment: .leading, spacing: 6) {
                Text(goalEntity.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(2)

                Text(goalEntity.kpi)
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
                .stroke(accentBlue.opacity(0.15), lineWidth: 4)
                .frame(width: 48, height: 48)

            // Progreso
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    isCompleted
                        ? LinearGradient(colors: [.green, .green], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [accentHighlight, accentBlue], startPoint: .topLeading, endPoint: .bottomTrailing),
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
                    .foregroundColor(accentBlue)
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
    let goalEntity = GoalEntity(
        planTitle: "Aprender SwiftUI",
        horizonDays: 42,
        kpi: "Completar 5 proyectos funcionales"
    )
    container.mainContext.insert(goalEntity)

    return GoalRowView(goalEntity: goalEntity)
        .padding()
        .background(Color(.systemGroupedBackground))
        .modelContainer(container)
}

#Preview("Completado") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: GoalEntity.self, StepEntity.self, configurations: config)
    let goalEntity = GoalEntity(
        planTitle: "Configurar proyecto",
        horizonDays: 7,
        kpi: "Proyecto funcionando",
        progress: 1.0
    )
    container.mainContext.insert(goalEntity)

    return GoalRowView(goalEntity: goalEntity)
        .padding()
        .background(Color(.systemGroupedBackground))
        .modelContainer(container)
}
