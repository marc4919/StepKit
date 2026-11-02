//
//  KitStepsEditorView.swift
//  StepKit
//
//  Editar la lista de pasos de un Kit con los controles del sistema: añadir, quitar y reordenar.
//  Se trabaja sobre un borrador: «Cancelar» lo deja todo como estaba y las fechas se ajustan al guardar.
//

import SwiftData
import SwiftUI

struct KitStepsEditorView: View {
    private static let maxSteps = 60
    private static let maxVisibleDateChanges = 6

    let kit: GoalEntity
    /// Se reordenó o se quitó un paso de un Kit generado con IA. Recibe qué cambió, para el asistente.
    var onPlanChanged: (String) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.syncManager) private var syncManager
    @State private var draft: StepListDraft
    @State private var form: StepForm?
    @State private var removal: StepRemoval?
    @State private var confirmingDiscard = false
    @State private var confirmingDates = false

    init(kit: GoalEntity, onPlanChanged: @escaping (String) -> Void = { _ in }) {
        self.kit = kit
        self.onPlanChanged = onPlanChanged
        _draft = State(initialValue: StepListDraft(kit: kit))
    }

    private struct StepForm: Identifiable {
        let step: StepDraft
        var id: UUID { step.id }
    }

    /// Paso con sesiones o avances: quitarlo pide confirmación.
    private struct StepRemoval: Identifiable {
        let id: UUID
        let sessionCount: Int
        let entryCount: Int
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(draft.pending) { step in
                        row(for: step)
                            .deleteDisabled(draft.totalCount == 1)
                    }
                    .onMove { draft.movePending(fromOffsets: $0, toOffset: $1) }
                    .onDelete { offsets in
                        offsets.first.map { requestRemoval(of: draft.pending[$0]) }
                    }
                    if draft.totalCount < Self.maxSteps {
                        addRow
                    }
                } footer: {
                    Text("Las fechas se ajustan al guardar.")
                }

                if !draft.completed.isEmpty {
                    Section("Terminados") {
                        ForEach(draft.completed) { step in
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
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        if draft.hasChanges { confirmingDiscard = true } else { dismiss() }
                    }
                    .accessibilityIdentifier("stepsEditor.cancel")
                    .confirmationDialog("¿Descartar los cambios?", isPresented: $confirmingDiscard, titleVisibility: .visible) {
                        Button("Descartar", role: .destructive) { dismiss() }
                        Button("Seguir editando", role: .cancel) {}
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", action: requestSave)
                        .disabled(!draft.hasChanges || draft.totalCount == 0)
                        .accessibilityIdentifier("stepsEditor.save")
                }
            }
            .sheet(item: $form) { form in
                StepDraftFormView(step: form.step) { saved in
                    if form.step.isNew, !draft.pending.contains(where: { $0.id == saved.id }) {
                        draft.add(saved)
                    } else {
                        draft.update(saved)
                    }
                }
            }
            .alert("¿Quitar este paso?", isPresented: removalAlertBinding, presenting: removal) { removal in
                Button("Quitar", role: .destructive) { draft.remove(removal.id) }
                Button("Cancelar", role: .cancel) {}
            } message: { removal in
                Text(removalMessage(removal))
            }
            .alert("Se moverán estas fechas", isPresented: $confirmingDates) {
                Button("Guardar", action: save)
                Button("Volver", role: .cancel) {}
            } message: {
                Text(dateChangesMessage)
            }
        }
        .interactiveDismissDisabled(draft.hasChanges)
    }

    private func row(for step: StepDraft) -> some View {
        Button {
            form = StepForm(step: step)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(step.title)
                    .foregroundStyle(step.isCompleted ? .secondary : .primary)
                    .multilineTextAlignment(.leading)
                Text(KitCreatorViewModel.durationText(step.minutes))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Abre el editor del paso")
    }

    private var addRow: some View {
        Button {
            form = StepForm(step: StepDraft(date: draft.lastPendingDate ?? Date()))
        } label: {
            Label {
                Text("Añadir paso")
            } icon: {
                Image(systemName: "plus.circle.fill")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .moveDisabled(true)
        .deleteDisabled(true)
        .accessibilityIdentifier("stepsEditor.add")
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

    private var dateChangesMessage: String {
        let changes = draft.dateChanges()
        var lines = changes.prefix(Self.maxVisibleDateChanges).map { change in
            let to = PlanGrouping.shortDate(change.to)
            return change.from.map { "\(change.title): \(PlanGrouping.shortDate($0)) → \(to)" } ?? "\(change.title): \(to)"
        }
        if changes.count > Self.maxVisibleDateChanges {
            lines.append(String(localized: "Y \(changes.count - Self.maxVisibleDateChanges) más."))
        }
        lines.append(String(localized: "Para mantener el orden y no pasar de \(PlanReschedule.maxStepsPerDay) pasos al día."))
        if let target = kit.targetDate, draft.passes(target: target) {
            lines.append(String(localized: "Algún paso quedaría después de la fecha final del Kit, el \(target.formatted(.dateTime.day().month(.abbreviated)))."))
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Cambios

    private func requestRemoval(of step: StepDraft) {
        guard !step.isNew, let entity = kit.orderedActiveSteps.first(where: { $0.id == step.id }) else {
            draft.remove(step.id)
            return
        }
        let sessionCount = StepListEditor.sessions(of: entity, in: kit, context: modelContext).count
        let stepID: UUID? = step.id
        let descriptor = FetchDescriptor<ProgressEntryEntity>(predicate: #Predicate { $0.stepID == stepID && $0.deletedAt == nil })
        let entryCount = (try? modelContext.fetchCount(descriptor)) ?? 0
        if sessionCount == 0 && entryCount == 0 {
            draft.remove(step.id)
        } else {
            removal = StepRemoval(id: step.id, sessionCount: sessionCount, entryCount: entryCount)
        }
    }

    private func requestSave() {
        if draft.dateChanges().isEmpty { save() } else { confirmingDates = true }
    }

    private func save() {
        let planChanges = draft.changesPlanStructure && kit.sourceModel != StepListDraft.manualSource
            ? draft.structureSummary : nil
        let detached = draft.apply(to: kit, context: modelContext)
        try? modelContext.save()
        StepListEditor.refreshReminders(of: detached, kit: kit)
        syncManager?.handleDataChange()
        NotificationService.shared.refreshStepReminders()
        if let planChanges { onPlanChanged(planChanges) }
        dismiss()
    }
}

extension StepListDraft {
    /// Valor de `sourceModel` en los Kits creados a mano.
    static let manualSource = "manual"
}

// MARK: - Formulario de un paso

/// Título, descripciones, fecha y tiempo de un paso del borrador: nuevo o ya existente.
struct StepDraftFormView: View {
    private static let maxTitleLength = 200

    @Environment(\.dismiss) private var dismiss
    @State private var step: StepDraft
    @State private var showsDetails: Bool
    @FocusState private var titleFocused: Bool
    private let original: StepDraft
    private let onSave: (StepDraft) -> Void
    /// Al crear un Kit a mano: sin fecha, el paso se reparte solo hasta la fecha final.
    private let dateIsOptional: Bool
    private let latestDate: Date?

    init(step: StepDraft, dateIsOptional: Bool = false, latestDate: Date? = nil, onSave: @escaping (StepDraft) -> Void) {
        original = step
        self.dateIsOptional = dateIsOptional
        self.latestDate = latestDate
        self.onSave = onSave
        _step = State(initialValue: step)
        // Con descripción ya escrita se ve abierto, para que no parezca que se ha perdido.
        _showsDetails = State(initialValue: !step.short.isEmpty || !step.long.isEmpty)
    }

    private var minuteOptions: [Int] {
        let base = [5, 10, 15, 20, 25, 30, 45, 60, 90, 120, 180, 240]
        return Array(Set(base + [step.minutes])).sorted()
    }

    private var earliestDate: Date {
        let today = Calendar.current.startOfDay(for: .now)
        return min(today, step.date.map(Calendar.current.startOfDay(for:)) ?? today)
    }

    /// Lo único obligatorio es el título: las descripciones van plegadas, como el contexto en el creador.
    @ViewBuilder private var detailsSection: some View {
        Section {
            Button {
                withAnimation(.formReveal) { showsDetails.toggle() }
            } label: {
                HStack(spacing: 12) {
                    IconChip(symbol: "text.badge.plus", color: .secondary, size: 28)
                    Text(showsDetails ? String(localized: "Ocultar detalles") : String(localized: "Añadir detalles (opcional)"))
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(showsDetails ? 180 : 0))
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("stepDraft.details")
            .sensoryFeedback(.selection, trigger: showsDetails)
            if showsDetails {
                TextField("Descripción breve", text: $step.short, axis: .vertical)
                    .lineLimit(2...4)
                    .textInputAutocapitalization(.sentences)
                    .transition(.formRow)
                TextEditor(text: $step.long)
                    .frame(minHeight: 120)
                    .accessibilityLabel("Descripción detallada")
                    .overlay(alignment: .topLeading) {
                        if step.long.isEmpty {
                            Text("Descripción detallada")
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    }
                    .transition(.formRow)
            }
        }
    }

    @ViewBuilder private var planningSection: some View {
        if !step.isCompleted {
            Section {
                if dateIsOptional {
                    Toggle(isOn: Binding(
                        get: { step.date != nil },
                        set: { step.date = $0 ? atNoon(earliestDate) : nil }
                    ).animation(.smooth)) {
                        Label { Text("Fecha") } icon: { IconChip(symbol: Symbols.calendar, color: MetaTint.date, size: 28) }
                    }
                    .accessibilityIdentifier("stepDraft.dateToggle")
                }
                if !dateIsOptional || step.date != nil {
                    DatePicker(selection: Binding(
                        get: { step.date ?? earliestDate },
                        set: { step.date = atNoon($0) }
                    ), in: earliestDate...max(latestDate ?? .distantFuture, earliestDate), displayedComponents: .date) {
                        if dateIsOptional {
                            Text("Día")
                        } else {
                            Label { Text("Fecha") } icon: { IconChip(symbol: Symbols.calendar, color: MetaTint.date, size: 28) }
                        }
                    }
                    .accessibilityIdentifier("stepDraft.date")
                }
                Picker(selection: $step.minutes) {
                    ForEach(minuteOptions, id: \.self) { Text(KitCreatorViewModel.durationText($0)).tag($0) }
                } label: {
                    Label { Text("Tiempo") } icon: { IconChip(symbol: Symbols.time, color: MetaTint.time, size: 28) }
                }
                .accessibilityIdentifier("stepDraft.minutes")
            } header: {
                Text("Planificación")
            } footer: {
                if dateIsOptional, step.date == nil {
                    Text("Sin fecha, el paso se reparte hasta la fecha final.")
                }
            }
        }
    }

    private func atNoon(_ date: Date) -> Date {
        Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Paso") {
                    TextField("Título del paso", text: $step.title)
                        .focused($titleFocused)
                        .textInputAutocapitalization(.sentences)
                        .onChange(of: step.title) { _, title in
                            if title.count > Self.maxTitleLength { step.title = String(title.prefix(Self.maxTitleLength)) }
                        }
                        .accessibilityIdentifier("stepDraft.title")
                }
                planningSection
                detailsSection
            }
            .navigationTitle(original.isNew ? "Nuevo paso" : "Editar paso")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(original.isNew ? "Añadir" : "Aceptar") {
                        onSave(step)
                        dismiss()
                    }
                    .disabled(!step.isValid)
                    .accessibilityIdentifier("stepDraft.save")
                }
            }
            .onAppear {
                if original.isNew { titleFocused = true }
            }
        }
        .interactiveDismissDisabled(step != original)
    }
}
