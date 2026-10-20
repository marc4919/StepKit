//
//  SessionSheets.swift
//  StepKit
//
//  v4.4: «Reservar sesión» y «Revisar sesión». Reservar tiempo no completa el paso.
//

import SwiftUI
import SwiftData

@MainActor
enum SessionLog {
    static func book(
        kit: GoalEntity,
        step: StepEntity?,
        startsAt: Date,
        minutes: Int,
        remind: Bool,
        context: ModelContext,
        now: Date = Date()
    ) throws -> WorkSessionEntity {
        let session = WorkSessionEntity(
            ownerID: kit.ownerID, kitID: kit.id, stepID: step?.id, startsAt: startsAt,
            durationMinutes: minutes, reminderEnabled: remind, createdAt: now, updatedAt: now
        )
        context.insert(session)
        try context.save()
        return session
    }

    static func move(_ session: WorkSessionEntity, to date: Date, context: ModelContext, now: Date = Date()) throws {
        session.startsAt = date
        session.markModified(at: now)
        try context.save()
    }

    static func remove(_ session: WorkSessionEntity, context: ModelContext, now: Date = Date()) throws {
        session.markAsDeleted(at: now)
        try context.save()
        NotificationService.shared.cancelReminder(forSession: session.id)
    }
}

struct BookSessionSheet: View {
    let kits: [GoalEntity]
    var initialKit: GoalEntity?
    var initialStep: StepEntity?
    var initialDate: Date = Date()

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.syncManager) private var syncManager
    @State private var kitID: UUID?
    @State private var stepID: UUID?
    @State private var date = Date()
    @State private var minutes = 30
    @State private var remind = true
    @State private var saveFailed = false

    private var kit: GoalEntity? { kits.first { $0.id == kitID } }
    private var step: StepEntity? { kit?.orderedActiveSteps.first { $0.id == stepID } }

    var body: some View {
        NavigationStack {
            Form {
                Section("Qué vas a hacer") {
                    Picker("Kit", selection: $kitID) {
                        ForEach(kits) { kit in
                            Text(kit.title).tag(Optional(kit.id))
                        }
                    }
                    if let kit {
                        Picker("Paso", selection: $stepID) {
                            Text("Sin paso concreto").tag(UUID?.none)
                            ForEach(kit.orderedActiveSteps.filter { !$0.isCompleted }) { step in
                                Text("\(kit.position(of: step)) · \(step.stepTitle)").tag(Optional(step.id))
                            }
                        }
                    }
                }
                Section {
                    DatePicker("Empieza", selection: $date)
                    Picker("Duración", selection: $minutes) {
                        Text("15 min").tag(15)
                        Text("30 min").tag(30)
                        Text("45 min").tag(45)
                        Text("1 h").tag(60)
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    Toggle("Recordármelo", isOn: $remind)
                } footer: {
                    Text("Reservar tiempo no completa el paso ni cambia tu disponibilidad semanal.")
                }
            }
            .navigationTitle("Reservar sesión")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { save() }
                        .disabled(kit == nil)
                        .accessibilityIdentifier("session.save")
                }
            }
            .alert("No se pudo reservar la sesión", isPresented: $saveFailed) {
                Button("Aceptar", role: .cancel) {}
            }
            .onChange(of: kitID) { _, _ in
                if step == nil { stepID = kit?.nextStep?.id }
            }
        }
        .onAppear {
            kitID = (initialKit ?? kits.first)?.id
            stepID = (initialStep ?? (initialKit ?? kits.first)?.nextStep)?.id
            date = Self.defaultStart(on: initialDate)
            if let step = initialStep ?? (initialKit ?? kits.first)?.nextStep {
                minutes = [15, 30, 45, 60].min { abs($0 - step.estimateMinutes) < abs($1 - step.estimateMinutes) } ?? 30
            }
        }
    }

    /// La próxima hora en punto, en el día elegido (o hoy si es pasado).
    static func defaultStart(on day: Date) -> Date {
        let calendar = Calendar.current
        let now = Date()
        let base = calendar.isDate(day, inSameDayAs: now) || day < now ? now : calendar.date(bySettingHour: 18, minute: 0, second: 0, of: day) ?? day
        guard calendar.isDate(base, inSameDayAs: now) else { return base }
        let nextHour = calendar.date(byAdding: .hour, value: 1, to: now) ?? now
        let hour = calendar.component(.hour, from: nextHour)
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: nextHour) ?? nextHour
    }

    private func save() {
        guard let kit else { return }
        do {
            let session = try SessionLog.book(kit: kit, step: step, startsAt: date, minutes: minutes,
                                              remind: remind, context: modelContext)
            syncManager?.handleDataChange()
            Task {
                if remind { await NotificationService.shared.requestAuthorizationIfNeeded() }
                await NotificationService.shared.scheduleReminder(for: session, kitTitle: kit.title,
                                                                  stepTitle: step?.stepTitle)
            }
            dismiss()
        } catch {
            saveFailed = true
        }
    }
}

struct ReviewSessionSheet: View {
    let session: WorkSessionEntity
    let kit: GoalEntity?
    let step: StepEntity?

    private enum Choice: Hashable { case move, keep, remove }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.syncManager) private var syncManager
    @State private var choice: Choice = .move
    @State private var newDate = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let step, let kit {
                        LabeledContent("Paso \(kit.position(of: step))", value: step.stepTitle)
                    } else if let kit {
                        LabeledContent("Kit", value: kit.title)
                    }
                    LabeledContent("Era", value: "\(session.startsAt.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute())) · \(session.durationMinutes) min")
                } footer: {
                    Text("Tu avance y la fecha deseada del Kit se conservan.")
                }
                Section("Qué quieres hacer") {
                    Picker("Opción", selection: $choice) {
                        Text("Moverla").tag(Choice.move)
                        Text(session.startsAt < Date() ? "Mantenerla como pasada" : "Mantenerla").tag(Choice.keep)
                        Text("Quitar la sesión").tag(Choice.remove)
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                    if choice == .move {
                        DatePicker("Nueva hora", selection: $newDate, in: Date()...)
                    }
                }
            }
            .navigationTitle("Revisar sesión")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirmar") { confirm() }
                }
            }
        }
        .onAppear {
            newDate = max(session.startsAt, BookSessionSheet.defaultStart(on: Date()))
        }
    }

    private func confirm() {
        switch choice {
        case .move:
            try? SessionLog.move(session, to: newDate, context: modelContext)
            Task {
                await NotificationService.shared.scheduleReminder(for: session, kitTitle: kit?.title ?? "StepKit",
                                                                  stepTitle: step?.stepTitle)
            }
        case .keep:
            break
        case .remove:
            try? SessionLog.remove(session, context: modelContext)
        }
        syncManager?.handleDataChange()
        dismiss()
    }
}
