//
//  StepEditSheetView.swift
//  StepKit
//

import SwiftData
import SwiftUI

struct StepEditSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.apiClient) private var apiClient: any APIClientProtocol
    @Environment(\.modelContext) private var modelContext
    @Environment(\.syncManager) private var syncManager
    @Environment(AuthManager.self) private var authManager

    let stepEntity: StepEntity

    @State private var draft: StepEditDraft
    @State private var showingSaveError = false

    init(stepEntity: StepEntity) {
        self.stepEntity = stepEntity
        _draft = State(initialValue: StepEditDraft(step: stepEntity))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Paso") {
                    TextField("Título del paso", text: $draft.title)
                        .textInputAutocapitalization(.sentences)
                        .accessibilityIdentifier("stepEdit.title")

                    TextField("Descripción breve", text: $draft.shortDescription, axis: .vertical)
                        .lineLimit(2...4)
                        .textInputAutocapitalization(.sentences)
                        .accessibilityIdentifier("stepEdit.shortDescription")
                }

                Section {
                    TextEditor(text: $draft.longDescription)
                        .frame(minHeight: 140)
                        .accessibilityLabel("Descripción detallada")
                        .accessibilityIdentifier("stepEdit.longDescription")
                } header: {
                    Text("Descripción detallada")
                } footer: {
                    Text("Describe la acción concreta necesaria para completar este paso.")
                }
                if !stepEntity.isCompleted {
                    planningSection
                }
            }
            .navigationTitle("Editar paso")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                    .accessibilityIdentifier("stepEdit.cancel")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        save()
                    }
                    .disabled(!draft.isValid || !draft.hasChanges(comparedTo: stepEntity))
                    .accessibilityIdentifier("stepEdit.save")
                }
            }
            .alert("No se pudo guardar el paso", isPresented: $showingSaveError) {
                Button("Aceptar", role: .cancel) { }
            } message: {
                Text("Los cambios no se han confirmado. Inténtalo de nuevo.")
            }
        }
        .interactiveDismissDisabled(draft.hasChanges(comparedTo: stepEntity))
    }

    // MARK: - Planificación

    private var kitSteps: [StepEntity] { stepEntity.goal?.orderedActiveSteps ?? [] }

    /// No se puede adelantar más allá del paso pendiente anterior: el orden del plan se mantiene.
    private var earliestDate: Date {
        let pending = kitSteps.filter { !$0.isCompleted }
        let today = Calendar.current.startOfDay(for: .now)
        guard let index = pending.firstIndex(where: { $0.id == stepEntity.id }), index > 0,
              let previous = pending[index - 1].suggestedDeadline else { return today }
        return max(today, Calendar.current.startOfDay(for: previous))
    }

    /// Pasos cuyo día cambia si se guarda la fecha elegida (incluido este, si su día estaba lleno).
    private var rescheduled: [UUID: Date] {
        guard draft.changesDate(of: stepEntity), let deadline = draft.deadline else { return [:] }
        return PlanReschedule.dates(for: kitSteps, overrides: [stepEntity.id: deadline])
    }

    private var minuteOptions: [Int] {
        let base = [5, 10, 15, 20, 25, 30, 45, 60, 90, 120, 180, 240]
        return Array(Set(base + [stepEntity.estimateMinutes])).sorted()
    }

    private var planningSection: some View {
        Section {
            DatePicker(selection: Binding(
                get: { draft.deadline ?? earliestDate },
                set: { newValue in withAnimation(.smooth) { draft.deadline = newValue } }
            ), in: earliestDate..., displayedComponents: .date) {
                Label { Text("Fecha") } icon: { IconChip(symbol: Symbols.calendar, color: MetaTint.date, size: 28) }
            }
            .accessibilityIdentifier("stepEdit.date")
            Picker(selection: Binding(
                get: { draft.estimateMinutes ?? stepEntity.estimateMinutes },
                set: { draft.estimateMinutes = $0 }
            )) {
                ForEach(minuteOptions, id: \.self) { Text(KitCreatorViewModel.durationText($0)).tag($0) }
            } label: {
                Label { Text("Tiempo") } icon: { IconChip(symbol: Symbols.time, color: MetaTint.time, size: 28) }
            }
            .accessibilityIdentifier("stepEdit.minutes")
            if draft.changesDate(of: stepEntity) {
                ReschedulePreview(steps: kitSteps, editedStepID: stepEntity.id, moves: rescheduled)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        } header: {
            Text("Planificación")
        } footer: {
            Text("Si la nueva fecha alcanza a los pasos siguientes, se mueven con ella: mismo orden y como mucho \(PlanReschedule.maxStepsPerDay) pasos al día.")
        }
    }

    private func save() {
        guard let ownerID = authManager.currentUser?.id else {
            showingSaveError = true
            return
        }

        do {
            let moves = rescheduled
            var applied = draft
            if let final = moves[stepEntity.id] { applied.deadline = final }
            try modelContext.transaction {
                _ = try applied.apply(to: stepEntity, expectedOwnerID: ownerID)
                // Efecto dominó: los pasos siguientes se mueven con la misma regla que el asistente.
                for step in stepEntity.goal?.orderedActiveSteps ?? [] where step.id != stepEntity.id {
                    guard let date = moves[step.id] else { continue }
                    step.suggestedDeadline = date
                    step.markModified()
                }
            }
            syncManager?.handleDataChange()
            if let kit = stepEntity.goal {
                KitAssistant.react(.edited, kit: kit, step: stepEntity, context: modelContext,
                                   apiClient: apiClient, token: authManager.token)
            }
            dismiss()
        } catch {
            showingSaveError = true
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: GoalEntity.self, StepEntity.self, configurations: config)
    let step = StepEntity(
        stepTitle: "Preparar material",
        descriptionShort: "Reúne lo necesario",
        descriptionLong: "Haz una lista y deja preparado todo el material antes de empezar.",
        estimateMinutes: 20
    )
    container.mainContext.insert(step)

    return StepEditSheetView(stepEntity: step)
        .modelContainer(container)
        .environment(AuthManager())
}

// MARK: - Vista previa del efecto dominó

/// Muestra, antes de guardar, qué pasos se mueven y a qué día. Las filas entran escalonadas.
private struct ReschedulePreview: View {
    let steps: [StepEntity]
    let editedStepID: UUID
    let moves: [UUID: Date]

    private var rows: [(number: Int, step: StepEntity, to: Date)] {
        steps.enumerated().compactMap { index, step in
            guard let to = moves[step.id] else { return nil }
            return (index + 1, step, to)
        }
    }

    private var others: Int { rows.filter { $0.step.id != editedStepID }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text(others == 0 ? "Solo cambia este paso" :
                        others == 1 ? "Para mantener el orden, se mueve 1 paso más" :
                        "Para mantener el orden, se mueven \(others) pasos más")
                    .font(.subheadline.weight(.semibold))
                    .contentTransition(.numericText())
            } icon: {
                Image(systemName: others == 0 ? "checkmark.circle.fill" : "arrow.trianglehead.branch")
                    .foregroundStyle(others == 0 ? .green : MetaTint.date)
                    .symbolEffect(.bounce, value: others)
            }
            ForEach(Array(rows.enumerated()), id: \.element.step.id) { order, row in
                RescheduleRow(number: row.number, title: row.step.stepTitle,
                              from: row.step.suggestedDeadline, to: row.to,
                              isEdited: row.step.id == editedStepID, order: order)
            }
        }
        .padding(.vertical, 4)
        .animation(.smooth, value: moves)
        .accessibilityElement(children: .combine)
    }
}

private struct RescheduleRow: View {
    let number: Int
    let title: String
    let from: Date?
    let to: Date
    let isEdited: Bool
    let order: Int
    @State private var shown = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.caption.bold().monospacedDigit())
                .foregroundStyle(isEdited ? .white : MetaTint.date)
                .frame(width: 24, height: 24)
                .background(isEdited ? AnyShapeStyle(MetaTint.date) : AnyShapeStyle(MetaTint.date.opacity(0.14)), in: .circle)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.medium)).lineLimit(2)
                HStack(spacing: 6) {
                    if let from {
                        Text(from.formatted(.dateTime.day().month(.abbreviated)))
                            .strikethrough()
                            .foregroundStyle(.secondary)
                        Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.secondary)
                    }
                    Text(to.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                        .fontWeight(.semibold)
                        .foregroundStyle(MetaTint.date)
                        .contentTransition(.numericText())
                }
                .font(.caption)
            }
        }
        .opacity(shown ? 1 : 0)
        .offset(x: shown ? 0 : 16)
        .onAppear {
            withAnimation(.smooth(duration: 0.4).delay(0.06 * Double(order))) { shown = true }
        }
    }
}
