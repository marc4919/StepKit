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

    /// Sesión propia, sin Kit: «Llamar al fontanero», «Gimnasio»…
    static func bookFree(
        title: String,
        ownerID: String,
        startsAt: Date,
        minutes: Int,
        remind: Bool,
        context: ModelContext,
        now: Date = Date()
    ) throws -> WorkSessionEntity {
        let id = UUID()
        let session = WorkSessionEntity(
            id: id, ownerID: ownerID, kitID: id, stepID: nil, startsAt: startsAt,
            durationMinutes: minutes, reminderEnabled: remind, createdAt: now, updatedAt: now
        )
        session.isFree = true
        session.title = String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200))
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

/// Qué se reserva desde el calendario: un rato para algo propio o una sesión de un Kit.
enum SessionBookingKind: String, Identifiable {
    case free, kit
    var id: String { rawValue }
}

/// La próxima hora en punto, en el día elegido (o hoy si es pasado).
enum SessionStart {
    static func `default`(on day: Date) -> Date {
        let calendar = Calendar.current
        let now = Date()
        let base = calendar.isDate(day, inSameDayAs: now) || day < now ? now : calendar.date(bySettingHour: 18, minute: 0, second: 0, of: day) ?? day
        guard calendar.isDate(base, inSameDayAs: now) else { return base }
        let nextHour = calendar.date(byAdding: .hour, value: 1, to: now) ?? now
        let hour = calendar.component(.hour, from: nextHour)
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: nextHour) ?? nextHour
    }
}

// MARK: - Algo propio

/// Reservar un rato para algo que no es de un Kit: escribir qué es (o elegir una idea), cuándo y cuánto.
struct BookFreeSessionSheet: View {
    let ownerID: String
    var initialDate: Date = Date()

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.syncManager) private var syncManager
    @State private var title = ""
    @State private var date = Date()
    @State private var minutes = 30
    @State private var remind = true
    @State private var saveFailed = false
    @FocusState private var titleFocused: Bool

    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("¿Qué vas a hacer?", text: $title)
                        .font(.title3)
                        .focused($titleFocused)
                        .submitLabel(.done)
                        .accessibilityIdentifier("session.freeTitle")
                } footer: {
                    Text("Un rato para ti que no forma parte de ningún Kit.")
                }
                SessionWhenSection(date: $date, minutes: $minutes, suggested: nil, allowsLongSessions: true)
                Section {
                    Toggle("Recordármelo", isOn: $remind)
                }
                if !trimmedTitle.isEmpty {
                    SessionSummary(symbol: "circle.fill", tint: .teal, title: trimmedTitle,
                                   detail: nil, date: date, minutes: minutes)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .animation(.smooth, value: trimmedTitle.isEmpty)
            .navigationTitle("Algo propio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Reservar") { save() }
                        .disabled(trimmedTitle.isEmpty)
                        .accessibilityIdentifier("session.save")
                }
            }
            .alert("No se pudo reservar la sesión", isPresented: $saveFailed) {
                Button("Aceptar", role: .cancel) {}
            }
        }
        .onAppear {
            date = SessionStart.default(on: initialDate)
            titleFocused = true
        }
    }

    private func save() {
        do {
            let session = try SessionLog.bookFree(title: trimmedTitle, ownerID: ownerID, startsAt: date,
                                                  minutes: minutes, remind: remind, context: modelContext)
            syncManager?.handleDataChange()
            Task {
                if remind { await NotificationService.shared.requestAuthorizationIfNeeded() }
                await NotificationService.shared.scheduleReminder(for: session, kitTitle: session.title ?? "StepKit",
                                                                  stepTitle: nil)
            }
            dismiss()
        } catch {
            saveFailed = true
        }
    }
}

// MARK: - Sesión de un Kit

/// Reservar tiempo para un Kit: se elige el Kit, el paso (el siguiente viene marcado), cuándo y cuánto.
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
    private var pendingSteps: [StepEntity] { kit?.orderedActiveSteps.filter { !$0.isCompleted } ?? [] }

    var body: some View {
        NavigationStack {
            Form {
                Section("Kit") {
                    ForEach(kits) { candidate in
                        Button {
                            withAnimation(.smooth) { choose(candidate) }
                        } label: {
                            HStack(spacing: 12) {
                                IconChip(symbol: Symbols.kits, color: .accentColor, size: 30)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(candidate.title).foregroundStyle(.primary)
                                    Text("\(candidate.completedStepCount) de \(candidate.activeStepCount) pasos")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                                if candidate.id == kitID {
                                    Image(systemName: "checkmark").font(.body.weight(.semibold)).foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                        .tint(.primary)
                        .accessibilityAddTraits(candidate.id == kitID ? .isSelected : [])
                    }
                }
                if kit != nil {
                    Section {
                        ForEach(pendingSteps) { candidate in
                            Button {
                                withAnimation(.smooth) {
                                    stepID = candidate.id
                                    minutes = candidate.estimateMinutes
                                }
                            } label: {
                                stepRow(candidate)
                            }
                            .tint(.primary)
                            .accessibilityAddTraits(candidate.id == stepID ? .isSelected : [])
                        }
                    } header: {
                        Text("Paso")
                    } footer: {
                        Text("Reservar tiempo no completa el paso.")
                    }
                    .transition(.opacity)
                }
                SessionWhenSection(date: $date, minutes: $minutes, suggested: step?.estimateMinutes)
                Section {
                    Toggle("Recordármelo", isOn: $remind)
                }
                if let kit {
                    SessionSummary(symbol: "circle.fill", tint: .blue, title: step?.stepTitle ?? kit.title,
                                   detail: step == nil ? nil : kit.title, date: date, minutes: minutes)
                }
            }
            .navigationTitle("Sesión de un Kit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Reservar") { save() }
                        .disabled(kit == nil)
                        .accessibilityIdentifier("session.save")
                }
            }
            .alert("No se pudo reservar la sesión", isPresented: $saveFailed) {
                Button("Aceptar", role: .cancel) {}
            }
        }
        .onAppear {
            date = SessionStart.default(on: initialDate)
            if let first = initialKit ?? kits.first { choose(first) }
            if let initialStep {
                stepID = initialStep.id
                minutes = initialStep.estimateMinutes
            }
        }
    }

    private func choose(_ candidate: GoalEntity) {
        kitID = candidate.id
        let next = candidate.nextStep
        stepID = next?.id
        if let next { minutes = next.estimateMinutes }
    }

    private func stepRow(_ candidate: StepEntity) -> some View {
        HStack(spacing: 12) {
            Text("\(kit?.position(of: candidate) ?? 0)")
                .font(.caption.bold().monospacedDigit())
                .foregroundStyle(candidate.id == stepID ? .white : Color.accentColor)
                .frame(width: 26, height: 26)
                .background(candidate.id == stepID ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color.accentColor.opacity(0.12)),
                            in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text(candidate.stepTitle).foregroundStyle(.primary).lineLimit(2)
                HStack(spacing: 8) {
                    Label("\(candidate.estimateMinutes) min", systemImage: Symbols.time)
                        .foregroundStyle(MetaTint.time)
                    if candidate.id == kit?.nextStep?.id {
                        Text("Siguiente").foregroundStyle(.secondary)
                    }
                }
                .font(.caption)
            }
            Spacer(minLength: 0)
        }
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

// MARK: - Piezas comunes

/// Cuándo y cuánto: fecha y hora, y la duración en botones (la del paso, si la hay, va primero).
private struct SessionWhenSection: View {
    @Binding var date: Date
    @Binding var minutes: Int
    let suggested: Int?
    /// Algo propio puede durar mucho más que un paso: de 5 min a 8 h, en un selector.
    var allowsLongSessions = false

    private static let longOptions = [5, 10, 15, 20, 30, 45, 60, 75, 90, 120, 150, 180, 240, 300, 360, 420, 480]

    private var options: [Int] {
        var values = [15, 30, 45, 60, 90]
        if let suggested, !values.contains(suggested) { values.append(suggested) }
        return values.sorted()
    }

    var body: some View {
        Section("Cuándo") {
            DatePicker(selection: $date, in: Calendar.current.startOfDay(for: .now)...) {
                Label { Text("Empieza") } icon: { IconChip(symbol: Symbols.calendar, color: MetaTint.date, size: 28) }
            }
            if allowsLongSessions {
                Picker(selection: $minutes) {
                    ForEach(Self.longOptions, id: \.self) { Text(KitCreatorViewModel.durationText($0)).tag($0) }
                } label: {
                    Label { Text("Duración") } icon: { IconChip(symbol: Symbols.time, color: MetaTint.time, size: 28) }
                }
                .accessibilityIdentifier("session.duration")
            } else {
            VStack(alignment: .leading, spacing: 10) {
                Label { Text("Duración") } icon: { IconChip(symbol: Symbols.time, color: MetaTint.time, size: 28) }
                FlowLayout(spacing: 8) {
                    ForEach(options, id: \.self) { value in
                        Button {
                            withAnimation(.smooth) { minutes = value }
                        } label: {
                            Text(KitCreatorViewModel.durationText(value))
                                .font(.subheadline.weight(minutes == value ? .semibold : .regular))
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        .tint(minutes == value ? MetaTint.time : .secondary)
                        .accessibilityAddTraits(minutes == value ? .isSelected : [])
                    }
                }
            }
            .padding(.vertical, 4)
            }
        }
    }
}

/// Resumen vivo de lo que se va a reservar, como quedará en el calendario.
private struct SessionSummary: View {
    let symbol: String
    let tint: Color
    let title: String
    let detail: String?
    let date: Date
    let minutes: Int

    private var end: Date { date.addingTimeInterval(TimeInterval(minutes * 60)) }

    var body: some View {
        Section("Así queda en tu calendario") {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: symbol).font(.caption).foregroundStyle(tint).padding(.top, 5)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline).contentTransition(.opacity)
                    if let detail { Text(detail).font(.subheadline).foregroundStyle(.secondary) }
                    Text("\(date.formatted(.dateTime.weekday(.wide).day().month(.wide))) · \(date.formatted(date: .omitted, time: .shortened))–\(end.formatted(date: .omitted, time: .shortened))")
                        .font(.subheadline)
                        .foregroundStyle(MetaTint.date)
                        .contentTransition(.numericText())
                }
            }
            .animation(.smooth, value: date)
            .animation(.smooth, value: minutes)
            .accessibilityElement(children: .combine)
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
                    if session.isFree {
                        LabeledContent("Sesión", value: session.title ?? "Sesión propia")
                    } else if let step, let kit {
                        LabeledContent("Paso \(kit.position(of: step))", value: step.stepTitle)
                    } else if let kit {
                        LabeledContent("Kit", value: kit.title)
                    }
                    LabeledContent("Era", value: "\(session.startsAt.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute())) · \(session.durationMinutes) min")
                } footer: {
                    Text("Tu avance y la fecha prevista del Kit se conservan.")
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
            newDate = max(session.startsAt, SessionStart.default(on: Date()))
        }
    }

    private func confirm() {
        switch choice {
        case .move:
            try? SessionLog.move(session, to: newDate, context: modelContext)
            Task {
                await NotificationService.shared.scheduleReminder(for: session, kitTitle: kit?.title ?? session.title ?? "StepKit",
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
