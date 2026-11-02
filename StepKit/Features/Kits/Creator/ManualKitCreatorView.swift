//
//  ManualKitCreatorView.swift
//  StepKit
//
//  Crear un Kit a mano: nombre, fecha final y pasos. Sin IA, sin permiso de IA y sin gastar usos.
//

import SwiftData
import SwiftUI

/// Lo que no depende de la pantalla: fechas de los pasos, límite del plan gratis y guardar el Kit.
enum ManualKit {
    static let maxSteps = 60

    /// Mismo criterio que el servidor al generar con IA: Kits activos, sin contar borrados ni terminados.
    static func reachesFreeLimit(kits: [GoalEntity], ownerID: String, isPremium: Bool) -> Bool {
        guard !isPremium else { return false }
        return kits.filter { $0.ownerID == ownerID && !$0.isRemoved && !$0.isCompleted }.count >= PlanLimits.freeActiveKits
    }

    /// Fecha de cada paso: los que no tienen una elegida se reparten entre hoy y la fecha final, y las
    /// elegidas se respetan. Solo se corrige lo que rompería el orden o se saldría de esas dos fechas.
    static func plannedDates(chosen: [Date?], from start: Date, to due: Date, calendar: Calendar = .current) -> [Date] {
        let first = calendar.startOfDay(for: start)
        let last = max(calendar.startOfDay(for: due), first)
        let days = calendar.dateComponents([.day], from: first, to: last).day ?? 0
        var previous = first
        return chosen.enumerated().map { index, date in
            let offset = chosen.count > 1 ? days * index / (chosen.count - 1) : 0
            let wanted = date.map(calendar.startOfDay(for:))
                ?? calendar.date(byAdding: .day, value: offset, to: first) ?? first
            let day = min(max(wanted, previous), last)
            previous = day
            return calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
        }
    }

    /// Fechas elegidas a mano que habrá que corregir, para enseñarlas antes de crear el Kit.
    static func dateChanges(of steps: [StepDraft], from start: Date, to due: Date, calendar: Calendar = .current) -> [StepListDraft.DateChange] {
        let planned = plannedDates(chosen: steps.map(\.date), from: start, to: due, calendar: calendar)
        return zip(steps, planned).compactMap { step, to in
            guard let from = step.date, !calendar.isDate(from, inSameDayAs: to) else { return nil }
            return StepListDraft.DateChange(title: step.title, from: from, to: to)
        }
    }

    /// Kit sin pasos, con lo escrito en el creador: los pasos se añaden después en el propio Kit.
    @discardableResult
    static func createEmpty(
        name: String,
        dueDate: Date,
        doneWhen: String = "",
        obstacles: String = "",
        startingPoint: String = "",
        stepMinutes: Int? = nil,
        ownerID: String,
        context: ModelContext,
        calendar: Calendar = .current,
        at now: Date = Date()
    ) -> GoalEntity {
        let kit = create(name: name, dueDate: dueDate, steps: [], ownerID: ownerID, context: context, calendar: calendar, at: now)
        kit.kpi = doneWhen.trimmingCharacters(in: .whitespacesAndNewlines)
        let obstacle = obstacles.trimmingCharacters(in: .whitespacesAndNewlines)
        if !obstacle.isEmpty { kit.risks = [obstacle] }
        if let stepMinutes { setStepMinutes(stepMinutes, for: kit) }
        try? context.save()
        try? ProgressLog.addKitNote(startingPoint, kit: kit, context: context, now: now)
        return kit
    }

    /// Tiempo con el que nacen los pasos de un Kit a mano: el que se eligió en el creador. Se guarda en
    /// este dispositivo porque es solo un valor inicial, y no merece un campo sincronizado.
    private static func stepMinutesKey(_ kit: GoalEntity) -> String { "manualKitStepMinutes.\(kit.id)" }

    static func setStepMinutes(_ minutes: Int, for kit: GoalEntity) {
        UserDefaults.standard.set(minutes, forKey: stepMinutesKey(kit))
    }

    static func stepMinutes(for kit: GoalEntity) -> Int {
        let saved = UserDefaults.standard.integer(forKey: stepMinutesKey(kit))
        return saved > 0 ? saved : kit.orderedActiveSteps.last?.estimateMinutes ?? 20
    }

    /// Añade un paso al final de un Kit ya creado: sin fecha, toma la del anterior o, si es el primero, la de hoy.
    @discardableResult
    static func addStep(_ step: StepDraft, to kit: GoalEntity, context: ModelContext, at now: Date = Date()) -> StepEntity {
        let previous = kit.orderedActiveSteps.last { !$0.isCompleted }?.suggestedDeadline
        let date = step.date ?? previous ?? Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: now) ?? now
        return StepListEditor.insert(id: step.id, title: step.title, minutes: step.minutes, date: date,
                                     short: step.short, long: step.long, into: kit, context: context, at: now)
    }

    @discardableResult
    static func create(
        name: String,
        dueDate: Date,
        steps: [StepDraft],
        ownerID: String,
        context: ModelContext,
        calendar: Calendar = .current,
        at now: Date = Date()
    ) -> GoalEntity {
        let due = calendar.startOfDay(for: dueDate)
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: due).day ?? 0
        let kit = GoalEntity(ownerID: ownerID, planTitle: name.trimmingCharacters(in: .whitespacesAndNewlines),
                             horizonDays: max(days + 1, 1), kpi: "", sourceModel: StepListDraft.manualSource,
                             createdAt: now, updatedAt: now)
        kit.targetDate = due
        context.insert(kit)
        let planned = plannedDates(chosen: steps.map(\.date), from: now, to: due, calendar: calendar)
        for (step, date) in zip(steps, planned) {
            StepListEditor.insert(id: step.id, title: step.title, minutes: step.minutes, date: date,
                                  short: step.short, long: step.long, into: kit, context: context, at: now)
        }
        return kit
    }
}

struct ManualKitCreatorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthManager.self) private var authManager

    let onCreated: (Goal) -> Void
    let onCancel: () -> Void

    @State private var name: String
    @State private var dueDate: Date?
    @State private var steps: [StepDraft] = []
    @State private var form: StepForm?
    @State private var confirmingDiscard = false
    @State private var confirmingDates = false
    @FocusState private var nameFocused: Bool

    private let todayStart = Calendar.current.startOfDay(for: .now)

    init(initialName: String = "", initialDueDate: Date? = nil,
         onCreated: @escaping (Goal) -> Void, onCancel: @escaping () -> Void) {
        self.onCreated = onCreated
        self.onCancel = onCancel
        _name = State(initialValue: initialName)
        _dueDate = State(initialValue: initialDueDate)
    }

    private struct StepForm: Identifiable {
        let step: StepDraft
        var id: UUID { step.id }
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var hasDraft: Bool { !trimmedName.isEmpty || !steps.isEmpty }
    private var canCreate: Bool { !trimmedName.isEmpty && dueDate != nil && !steps.isEmpty }

    /// Un botón apagado sin motivo parece roto: se dice qué falta.
    private var missingField: String? {
        if trimmedName.isEmpty { return String(localized: "Escribe el nombre del Kit para continuar.") }
        if dueDate == nil { return String(localized: "Elige una fecha para continuar.") }
        return steps.isEmpty ? String(localized: "Añade al menos un paso para continuar.") : nil
    }

    var body: some View {
        List {
            Section("Nombre") {
                TextField("Por ejemplo, Aprender a hacer pan", text: $name)
                    .focused($nameFocused)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.done)
                    .onChange(of: name) { _, value in
                        if value.count > 200 { name = String(value.prefix(200)) }
                    }
                    .moveDisabled(true)
                    .deleteDisabled(true)
                    .accessibilityIdentifier("manualKit.name")
            }
            Section {
                KitDueDateField(dueDate: $dueDate, todayStart: todayStart)
                    .moveDisabled(true)
                    .deleteDisabled(true)
            }
            Section {
                ForEach(steps) { step in
                    Button {
                        form = StepForm(step: step)
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(step.title).foregroundStyle(.primary).multilineTextAlignment(.leading)
                            Text(detail(of: step)).font(.subheadline).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Abre el editor del paso")
                }
                .onMove { steps.move(fromOffsets: $0, toOffset: $1) }
                .onDelete { steps.remove(atOffsets: $0) }
                if steps.count < ManualKit.maxSteps {
                    Button {
                        form = StepForm(step: StepDraft(date: nil))
                    } label: {
                        Label { Text("Añadir paso") } icon: { Image(systemName: "plus.circle.fill") }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(.rect)
                    }
                    .moveDisabled(true)
                    .deleteDisabled(true)
                    .accessibilityIdentifier("manualKit.addStep")
                }
            } header: {
                Text("Pasos")
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Los pasos sin fecha se reparten hasta la fecha final.")
                    if let missingField {
                        Text(missingField).accessibilityIdentifier("manualKit.missing")
                    }
                }
            }
        }
        .environment(\.editMode, .constant(.active))
        .navigationTitle("Nuevo Kit")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") {
                    if hasDraft { confirmingDiscard = true } else { onCancel() }
                }
                .confirmationDialog("¿Descartar este Kit?", isPresented: $confirmingDiscard, titleVisibility: .visible) {
                    Button("Descartar", role: .destructive, action: onCancel)
                    Button("Seguir editando", role: .cancel) {}
                } message: {
                    Text("Se perderá lo que has escrito.")
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Crear", action: requestCreate)
                    .disabled(!canCreate)
                    .accessibilityIdentifier("manualKit.create")
            }
        }
        .sheet(item: $form) { form in
            StepDraftFormView(step: form.step, dateIsOptional: true, unsetDateNote: "Sin fecha, el paso se reparte hasta la fecha final.", latestDate: dueDate) { saved in
                if let index = steps.firstIndex(where: { $0.id == saved.id }) {
                    steps[index] = saved.normalized
                } else {
                    steps.append(saved.normalized)
                }
            }
        }
        .alert("Se moverán estas fechas", isPresented: $confirmingDates) {
            Button("Crear", action: create)
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text(dateChangesMessage)
        }
        .onAppear {
            if trimmedName.isEmpty { nameFocused = true }
        }
    }

    private func detail(of step: StepDraft) -> String {
        let minutes = KitCreatorViewModel.durationText(step.minutes)
        guard let date = step.date else { return minutes }
        return "\(PlanGrouping.shortDate(date)) · \(minutes)"
    }

    private var dateChangesMessage: String {
        guard let dueDate else { return "" }
        var lines = ManualKit.dateChanges(of: steps, from: .now, to: dueDate).map { change in
            let to = PlanGrouping.shortDate(change.to)
            return change.from.map { "\(change.title): \(PlanGrouping.shortDate($0)) → \(to)" } ?? "\(change.title): \(to)"
        }
        lines.append(String(localized: "Para mantener el orden de los pasos, dentro de la fecha final."))
        return lines.joined(separator: "\n")
    }

    private func requestCreate() {
        guard let dueDate else { return }
        if ManualKit.dateChanges(of: steps, from: .now, to: dueDate).isEmpty {
            create()
        } else {
            confirmingDates = true
        }
    }

    private func create() {
        guard let dueDate, let ownerID = authManager.currentUser?.id else { return }
        let kit = ManualKit.create(name: name, dueDate: dueDate, steps: steps, ownerID: ownerID, context: modelContext)
        try? modelContext.save()
        onCreated(kit.toGoal())
    }
}
