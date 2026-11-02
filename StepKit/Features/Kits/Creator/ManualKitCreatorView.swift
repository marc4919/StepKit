//
//  ManualKitCreatorView.swift
//  StepKit
//
//  Crear un Kit a mano: nombre y fecha final; los pasos se añaden en el propio Kit. Sin IA, sin permiso de IA y sin gastar usos.
//

import SwiftData
import SwiftUI

/// Lo que no depende de la pantalla: límite del plan gratis y guardar el Kit.
enum ManualKit {
    /// Mismo criterio que el servidor al generar con IA: Kits activos, sin contar borrados ni terminados.
    static func reachesFreeLimit(kits: [GoalEntity], ownerID: String, isPremium: Bool) -> Bool {
        guard !isPremium else { return false }
        return kits.filter { $0.ownerID == ownerID && !$0.isRemoved && !$0.isCompleted }.count >= PlanLimits.freeActiveKits
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
        let due = calendar.startOfDay(for: dueDate)
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: due).day ?? 0
        let kit = GoalEntity(ownerID: ownerID, planTitle: name.trimmingCharacters(in: .whitespacesAndNewlines),
                             horizonDays: max(days + 1, 1), kpi: "", sourceModel: StepListDraft.manualSource,
                             createdAt: now, updatedAt: now)
        kit.targetDate = due
        context.insert(kit)
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
}

struct ManualKitCreatorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthManager.self) private var authManager

    let onCreated: (Goal) -> Void
    let onCancel: () -> Void

    @State private var name: String
    @State private var dueDate: Date?
    @State private var confirmingDiscard = false
    @FocusState private var nameFocused: Bool

    private let todayStart = Calendar.current.startOfDay(for: .now)

    init(initialName: String = "", initialDueDate: Date? = nil,
         onCreated: @escaping (Goal) -> Void, onCancel: @escaping () -> Void) {
        self.onCreated = onCreated
        self.onCancel = onCancel
        _name = State(initialValue: initialName)
        _dueDate = State(initialValue: initialDueDate)
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canCreate: Bool { !trimmedName.isEmpty && dueDate != nil }

    /// Un botón apagado sin motivo parece roto: se dice qué falta.
    private var missingField: String? {
        if trimmedName.isEmpty { return String(localized: "Escribe el nombre del Kit para continuar.") }
        return dueDate == nil ? String(localized: "Elige una fecha para continuar.") : nil
    }

    var body: some View {
        Form {
            Section("Nombre") {
                TextField("Por ejemplo, Aprender a hacer pan", text: $name)
                    .focused($nameFocused)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.done)
                    .onChange(of: name) { _, value in
                        if value.count > 200 { name = String(value.prefix(200)) }
                    }
                    .accessibilityIdentifier("manualKit.name")
            }
            Section {
                KitDueDateField(dueDate: $dueDate, todayStart: todayStart)
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Los pasos los añadirás en el Kit.")
                    if let missingField {
                        Text(missingField).accessibilityIdentifier("manualKit.missing")
                    }
                }
            }
        }
        .navigationTitle("Nuevo Kit")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") {
                    if trimmedName.isEmpty { onCancel() } else { confirmingDiscard = true }
                }
                .confirmationDialog("¿Descartar este Kit?", isPresented: $confirmingDiscard, titleVisibility: .visible) {
                    Button("Descartar", role: .destructive, action: onCancel)
                    Button("Seguir editando", role: .cancel) {}
                } message: {
                    Text("Se perderá lo que has escrito.")
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Crear", action: create)
                    .disabled(!canCreate)
                    .accessibilityIdentifier("manualKit.create")
            }
        }
        .onAppear {
            if trimmedName.isEmpty { nameFocused = true }
        }
    }

    private func create() {
        guard let dueDate, let ownerID = authManager.currentUser?.id else { return }
        let kit = ManualKit.createEmpty(name: name, dueDate: dueDate, ownerID: ownerID, context: modelContext)
        onCreated(kit.toGoal())
    }
}
