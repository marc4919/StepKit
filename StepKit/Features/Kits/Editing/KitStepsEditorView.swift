//
//  KitStepsEditorView.swift
//  StepKit
//
//  Editar la lista de pasos de un Kit con los controles del sistema: añadir, quitar y reordenar.
//  Los cambios se aplican al momento, como en Recordatorios; «Hecho» solo cierra la hoja.
//

import SwiftData
import SwiftUI

struct KitStepsEditorView: View {
    private static let maxSteps = 60
    private static let maxTitleLength = 200

    let kit: GoalEntity

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.syncManager) private var syncManager
    @State private var newTitle = ""
    @State private var editingStep: StepEntity?
    @State private var removal: StepRemoval?
    @FocusState private var addingStep: Bool

    /// Paso con sesiones o avances: quitarlo pide confirmación.
    private struct StepRemoval: Identifiable {
        let step: StepEntity
        let sessionCount: Int
        let entryCount: Int
        var id: UUID { step.id }
    }

    private var steps: [StepEntity] { kit.orderedActiveSteps }
    private var pending: [StepEntity] { steps.filter { !$0.isCompleted } }
    private var completed: [StepEntity] { steps.filter(\.isCompleted) }

    private var trimmedTitle: String { newTitle.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var passesFinalDate: Bool {
        guard let target = kit.targetDate, let last = pending.compactMap(\.suggestedDeadline).max() else { return false }
        return Calendar.current.startOfDay(for: last) > Calendar.current.startOfDay(for: target)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(pending) { step in
                        row(for: step)
                            .deleteDisabled(steps.count == 1)
                    }
                    .onMove(perform: movePending)
                    .onDelete { offsets in
                        offsets.first.map { requestRemoval(of: pending[$0]) }
                    }
                    if steps.count < Self.maxSteps {
                        addRow
                    }
                } footer: {
                    if passesFinalDate, let target = kit.targetDate {
                        Text(String(localized: "Algún paso quedaría después de la fecha final del Kit, el \(target.formatted(.dateTime.day().month(.abbreviated)))."))
                    }
                }

                if !completed.isEmpty {
                    Section("Terminados") {
                        ForEach(completed) { step in
                            row(for: step)
                                .moveDisabled(true)
                                .deleteDisabled(true)
                        }
                    }
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Editar pasos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Hecho") { dismiss() }
                        .accessibilityIdentifier("stepsEditor.done")
                }
            }
            .sheet(item: $editingStep) { step in
                StepEditSheetView(stepEntity: step)
            }
            .alert("¿Quitar este paso?", isPresented: removalAlertBinding, presenting: removal) { removal in
                Button("Quitar", role: .destructive) { remove(removal.step) }
                Button("Cancelar", role: .cancel) {}
            } message: { removal in
                Text(removalMessage(removal))
            }
        }
    }

    private func row(for step: StepEntity) -> some View {
        Button {
            editingStep = step
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(step.stepTitle)
                    .foregroundStyle(step.isCompleted ? .secondary : .primary)
                    .multilineTextAlignment(.leading)
                Text(detail(of: step))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Abre el editor del paso")
    }

    private func detail(of step: StepEntity) -> String {
        let minutes = String(localized: "\(step.estimateMinutes) min")
        guard let date = step.suggestedDeadline else { return minutes }
        return "\(PlanGrouping.shortDate(date)) · \(minutes)"
    }

    private var addRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            TextField("Añadir paso", text: $newTitle)
                .focused($addingStep)
                .submitLabel(.next)
                .textInputAutocapitalization(.sentences)
                .onSubmit(addStep)
                .onChange(of: newTitle) { _, title in
                    if title.count > Self.maxTitleLength { newTitle = String(title.prefix(Self.maxTitleLength)) }
                }
                .accessibilityIdentifier("stepsEditor.add")
        }
        .moveDisabled(true)
        .deleteDisabled(true)
    }

    private var removalAlertBinding: Binding<Bool> {
        Binding(get: { removal != nil }, set: { if !$0 { removal = nil } })
    }

    private func removalMessage(_ removal: StepRemoval) -> String {
        var lines: [String] = []
        if removal.sessionCount > 0 {
            lines.append(String(localized: "Sesiones reservadas: \(removal.sessionCount). Pasarán al Kit."))
        }
        if removal.entryCount > 0 {
            lines.append(String(localized: "Avances: \(removal.entryCount). Se conservan en el Registro."))
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Cambios

    private func addStep() {
        let title = trimmedTitle
        // Intro sin texto no cierra el campo de golpe, pero tampoco crea un paso vacío.
        guard !title.isEmpty, steps.count < Self.maxSteps else { return }
        let now = Date()
        let date = pending.last?.suggestedDeadline ?? kit.orderedActiveSteps.last?.suggestedDeadline ?? now
        let step = withAnimation {
            StepListEditor.insert(title: title, minutes: 20, date: date, into: kit, context: modelContext, at: now)
        }
        StepListEditor.settleDate(of: step, in: kit, at: now)
        newTitle = ""
        addingStep = true
        persist()
    }

    private func movePending(from source: IndexSet, to destination: Int) {
        guard let offset = source.first else { return }
        let step = pending[offset]
        var reordered = pending
        reordered.move(fromOffsets: source, toOffset: destination)
        guard let position = reordered.firstIndex(where: { $0.id == step.id }) else { return }
        // La lista muestra solo los pendientes; el orden del Kit también incluye los terminados.
        let others = steps.filter { $0.id != step.id }
        let index = position + 1 < reordered.count
            ? others.firstIndex { $0.id == reordered[position + 1].id } ?? others.count
            : others.count
        let now = Date()
        StepListEditor.move(step, to: index, in: kit, at: now)
        StepListEditor.settleDate(of: step, in: kit, at: now)
        persist()
    }

    private func requestRemoval(of step: StepEntity) {
        let sessionCount = StepListEditor.sessions(of: step, in: kit, context: modelContext).count
        let stepID: UUID? = step.id
        let descriptor = FetchDescriptor<ProgressEntryEntity>(predicate: #Predicate { $0.stepID == stepID && $0.deletedAt == nil })
        let entryCount = (try? modelContext.fetchCount(descriptor)) ?? 0
        if sessionCount == 0 && entryCount == 0 {
            remove(step)
        } else {
            removal = StepRemoval(step: step, sessionCount: sessionCount, entryCount: entryCount)
        }
    }

    private func remove(_ step: StepEntity) {
        // Siempre queda un paso, aunque el borrado llegue de una confirmación ya abierta.
        guard steps.count > 1 else { return }
        let detached = withAnimation {
            StepListEditor.remove(step, from: kit, context: modelContext)
        }
        StepListEditor.refreshReminders(of: detached, kit: kit)
        persist()
    }

    private func persist() {
        kit.markModified()
        try? modelContext.save()
        syncManager?.handleDataChange()
        NotificationService.shared.refreshStepReminders()
    }
}
