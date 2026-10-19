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
    @State private var showingEditor = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.syncManager) private var syncManager

    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var stateLabel: String {
        if stepEntity.isCompleted { return "Completado" }
        if stepEntity.goal?.nextStep?.id == stepEntity.id { return "Siguiente" }
        return "Pendiente"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Eyebrow(text: "Paso \(stepNumber) · \(stateLabel)",
                            color: stepEntity.isCompleted ? MetaTint.done : .accentColor)
                    Text(stepEntity.stepTitle)
                        .font(.largeTitle.bold())
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                }
                if !stepEntity.descriptionShort.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Al terminar").font(.headline)
                        Text(stepEntity.descriptionShort).foregroundStyle(.secondary)
                    }
                }
                ViewThatFits {
                    HStack(spacing: 8) { chips }
                    VStack(alignment: .leading, spacing: 8) { chips }
                }
                if !stepEntity.descriptionLong.isEmpty, stepEntity.descriptionLong != stepEntity.descriptionShort {
                    PlainCard {
                        Eyebrow(text: "Descripción", color: .secondary)
                        Text(stepEntity.descriptionLong)
                    }
                }
                if !stepEntity.adaptsTo.isEmpty {
                    TintCard {
                        HStack(alignment: .top, spacing: 12) {
                            NextMark().padding(.top, 2)
                            VStack(alignment: .leading, spacing: 2) {
                                Eyebrow(text: "Planificación recomendada")
                                Text(stepEntity.adaptsTo).font(.headline)
                            }
                        }
                    }
                }
                PlainCard {
                    Toggle(isOn: Binding(
                        get: { stepEntity.notificationEnabled },
                        set: { _ in toggleStepNotification() }
                    )) {
                        Label {
                            Text("Recordatorio")
                        } icon: {
                            IconChip(symbol: "bell.fill", color: .red, size: 28)
                        }
                    }
                    .accessibilityHint("Activa o desactiva el recordatorio de este paso")
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(alignment: .top) { BrandGlow() }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(stepEntity.goal?.title ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Editar paso", systemImage: "pencil") {
                    showingEditor = true
                }
                .accessibilityIdentifier("step.edit")
                .accessibilityHint("Permite cambiar el título y las descripciones del paso")
            }
        }
        .safeAreaInset(edge: .bottom) { bottomActions }
        .sheet(isPresented: $showingEditor) {
            StepEditSheetView(stepEntity: stepEntity)
        }
    }

    @ViewBuilder private var chips: some View {
        MetaChip(symbol: Symbols.time,
                 text: StepDetailHelpers.formatMinutes(stepEntity.estimateMinutes),
                 color: MetaTint.time)
        MetaChip(symbol: Symbols.effort,
                 text: "Esfuerzo \(StepDetailHelpers.effortLevelText(for: stepEntity.effortLevel).lowercased())",
                 color: MetaTint.effort)
        if let deadline = stepEntity.suggestedDeadline {
            MetaChip(symbol: Symbols.calendar,
                     text: deadline.formatted(.dateTime.day().month(.abbreviated)),
                     color: MetaTint.date)
        }
    }

    private var completionButton: some View {
        Button {
            withAnimation { toggleStepCompletion() }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } label: {
            Label(stepEntity.isCompleted ? "Marcar como pendiente" : "Marcar como completado",
                  systemImage: stepEntity.isCompleted ? "arrow.uturn.backward" : "checkmark")
                .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("step.toggleCompletion")
    }

    @ViewBuilder private var bottomActions: some View {
        let compactHeight = verticalSizeClass == .compact
        Group {
            if stepEntity.isCompleted {
                completionButton.buttonStyle(.bordered)
            } else {
                completionButton.buttonStyle(.borderedProminent)
            }
        }
        .controlSize(compactHeight ? .regular : .large)
        .padding(.horizontal)
        .padding(.vertical, compactHeight ? 6 : 10)
        .background(.bar)
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
            #if DEBUG
            print("Step notification preference persistence failed")
            #endif
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
            #if DEBUG
            print("Step completion persistence failed")
            #endif
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
