//
//  StepDetailView.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on 8/10/25.
//

import SwiftUI
import SwiftData

struct StepDetailView: View {
    @Bindable var stepEntity: StepEntity
    var stepNumber: Int = 1
    @State private var buttonScale: CGFloat = 1.0
    @State private var iconRotation: Double = 0
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.syncManager) private var syncManager

    var body: some View {
        ScrollView {
            StepDetailCardsView(stepEntity: stepEntity)
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 120)
        }
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) {
            StepDetailBottomActionView(
                stepEntity: stepEntity,
                buttonScale: $buttonScale,
                iconRotation: $iconRotation,
                onToggle: toggleStepCompletion
            )
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            StepDetailHeaderView(stepTitle: stepEntity.stepTitle, stepNumber: stepNumber)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        toggleStepNotification()
                    }
                } label: {
                    Image(systemName: stepEntity.notificationEnabled ? "bell.fill" : "bell.slash")
                        .foregroundStyle(stepEntity.notificationEnabled ? Color.accentColor : .secondary)
                        .symbolEffect(.bounce, value: stepEntity.notificationEnabled)
                }
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(stepEntity.notificationEnabled ? "Desactivar notificación" : "Activar notificación")
                .accessibilityValue(stepEntity.notificationEnabled ? "Activo" : "Inactivo")
                .accessibilityHint("Activa o desactiva el recordatorio de este paso")
            }
        }
    }

    // MARK: - Step Notification Toggle
    private func toggleStepNotification() {
        stepEntity.notificationEnabled.toggle()
        stepEntity.markModified()

        if stepEntity.notificationEnabled {
            Task {
                await NotificationService.shared.scheduleNotification(for: stepEntity)
            }
        } else {
            NotificationService.shared.cancelNotification(for: stepEntity.id)
        }

        do {
            try modelContext.save()
        } catch {
            print("Error al guardar notificación del step: \(error)")
        }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: - Actions
    private func toggleStepCompletion() {
        // Actualizar el StepEntity directamente
        stepEntity.isCompleted.toggle()
        stepEntity.markModified()  // También marca el goal parent

        // Actualizar progreso del goal
        if let goalEntity = stepEntity.goal {
            goalEntity.progress = goalEntity.computedProgress
            goalEntity.markModified()
        }

        // Guardar cambios
        do {
            try modelContext.save()

            // Trigger sync después de cambio
            syncManager?.handleDataChange()
        } catch {
            print("Error al guardar step: \(error)")
        }
    }
}

#Preview("Pendiente") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: GoalEntity.self, StepEntity.self, configurations: config)
    let stepEntity = StepEntity(
        stepTitle: "Paso pendiente",
        descriptionShort: "Descripción corta",
        descriptionLong: "Descripción larga del paso",
        estimateMinutes: 45,
        suggestedDeadline: Date(),
        effortLevel: "medium",
        adaptsTo: "Se adapta a tu disponibilidad",
        isCompleted: false
    )
    container.mainContext.insert(stepEntity)

    return NavigationStack {
        StepDetailView(stepEntity: stepEntity, stepNumber: 1)
    }
    .modelContainer(container)
}

#Preview("Completado") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: GoalEntity.self, StepEntity.self, configurations: config)
    let stepEntity = StepEntity(
        stepTitle: "Paso completado",
        descriptionShort: "Descripción corta",
        descriptionLong: "Descripción larga del paso completado",
        estimateMinutes: 30,
        suggestedDeadline: Date(),
        effortLevel: "low",
        adaptsTo: "",
        isCompleted: true
    )
    container.mainContext.insert(stepEntity)

    return NavigationStack {
        StepDetailView(stepEntity: stepEntity, stepNumber: 3)
    }
    .modelContainer(container)
}
