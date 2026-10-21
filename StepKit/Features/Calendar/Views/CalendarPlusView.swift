//
//  CalendarPlusView.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on 7/12/25.
//
//  El mes arriba y la agenda del día elegido justo debajo. Al tocar un día la
//  agenda se actualiza en el sitio y solo hace scroll si no se ve. Las próximas
//  sesiones quedan como acceso al final. Solo las sesiones reservadas son
//  compromisos; sugerencias y fecha prevista orientan.
//

import SwiftUI
import SwiftData

private enum CalendarRoute: Hashable {
    case upcomingSessions
}

struct CalendarPlusView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.syncManager) private var syncManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AuthManager.self) private var authManager
    @Query(filter: #Predicate<GoalEntity> { !$0.isDeleted },
           sort: \GoalEntity.createdAt,
           order: .reverse)
    private var goalEntities: [GoalEntity]
    @Query(sort: \WorkSessionEntity.startsAt) private var allSessions: [WorkSessionEntity]

    @State private var selectedDate: Date = Date()
    @State private var revealToken = 0
    @State private var dayVisible = true
    @State private var showingKitCreator = false
    @State private var showingBookSession = false
    @State private var reviewingSession: WorkSessionEntity?
    @State private var navigationPath = NavigationPath()

    private static let dayAnchor = "calendar.day"

    private var ownerID: String? { authManager.currentUser?.id }

    private var visibleGoalEntities: [GoalEntity] {
        guard let ownerID else { return [] }
        return goalEntities.filter { $0.ownerID == ownerID }
    }

    /// En curso, el último que avanzaste primero (por defecto al reservar).
    private var activeKits: [GoalEntity] {
        visibleGoalEntities.filter { !$0.isCompleted }.sorted { $0.lastActivity > $1.lastActivity }
    }

    private var sessions: [WorkSessionEntity] {
        guard let ownerID else { return [] }
        let kitIDs = Set(visibleGoalEntities.map(\.id))
        return allSessions.filter { $0.ownerID == ownerID && $0.deletedAt == nil && kitIDs.contains($0.kitID) }
    }

    private var upcomingSessions: [WorkSessionEntity] {
        let now = Date()
        return sessions.filter { $0.endsAt >= now }
    }

    private var marks: [DateComponents: Set<CalendarMark>] {
        var result: [DateComponents: Set<CalendarMark>] = [:]
        func add(_ date: Date, _ mark: CalendarMark) {
            result[DateComponents.day(of: date), default: []].insert(mark)
        }
        for kit in activeKits {
            for step in kit.orderedActiveSteps where !step.isCompleted {
                if let date = step.suggestedDeadline { add(date, .suggestion) }
            }
            if let date = kit.dueDate { add(date, .wantedDate) }
        }
        for session in sessions { add(session.startsAt, .session) }
        return result
    }

    private var sessionsForSelectedDate: [WorkSessionEntity] {
        sessions.filter { Calendar.current.isDate($0.startsAt, inSameDayAs: selectedDate) }
    }

    private var stepsForSelectedDate: [StepEntity] {
        visibleGoalEntities.flatMap(\.orderedActiveSteps)
            .filter { step in
                guard let deadline = step.suggestedDeadline else { return false }
                return Calendar.current.isDate(deadline, inSameDayAs: selectedDate)
            }
    }

    private var goalsForSelectedDate: [GoalEntity] {
        visibleGoalEntities.filter { kit in
            guard let dueDate = kit.dueDate else { return false }
            return Calendar.current.isDate(dueDate, inSameDayAs: selectedDate)
        }
    }

    private var selectedDayIsPast: Bool {
        selectedDate < Calendar.current.startOfDay(for: Date())
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if visibleGoalEntities.isEmpty {
                    emptyCalendar
                } else {
                    calendarList
                }
            }
            .navigationTitle("Calendario")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Hoy") {
                        selectedDate = Date()
                        revealToken += 1
                    }
                    .accessibilityIdentifier("calendar.today")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Reservar sesión", systemImage: Symbols.session) { showingBookSession = true }
                            .disabled(activeKits.isEmpty)
                        Button("Crear Kit para este día", systemImage: "plus.circle") { showingKitCreator = true }
                    } label: {
                        Label("Añadir", systemImage: "plus")
                    }
                    .accessibilityIdentifier("calendar.add")
                }
            }
            .navigationDestination(for: GoalNavigation.self) { nav in
                if let goalEntity = visibleGoalEntities.first(where: { $0.id == nav.id }) {
                    KitDetailView(kitEntity: goalEntity)
                }
            }
            .navigationDestination(for: StepNavigation.self) { nav in
                if let step = visibleGoalEntities.flatMap(\.steps).first(where: { $0.id == nav.id }) {
                    StepDetailView(stepEntity: step, stepNumber: step.goal?.position(of: step) ?? 1)
                } else {
                    ContentUnavailableView("Paso no encontrado", systemImage: "exclamationmark.triangle")
                }
            }
            .navigationDestination(for: CalendarRoute.self) { _ in
                UpcomingSessionsView(sessions: upcomingSessions, kits: visibleGoalEntities)
            }
            .sheet(isPresented: $showingBookSession) {
                BookSessionSheet(kits: activeKits, initialDate: selectedDate)
            }
            .sheet(item: $reviewingSession) { session in
                let kit = visibleGoalEntities.first { $0.id == session.kitID }
                ReviewSessionSheet(session: session, kit: kit,
                                   step: kit?.orderedActiveSteps.first { $0.id == session.stepID })
            }
            .fullScreenCover(isPresented: $showingKitCreator) {
                KitCreatorView(onKitCreated: { _ in }, initialDate: selectedDate)
            }
            .task(id: upcomingSessions.prefix(5).map(\.updatedAt)) {
                // Las sesiones pueden llegar por sync desde otro dispositivo.
                for session in upcomingSessions.prefix(5) {
                    guard let kit = visibleGoalEntities.first(where: { $0.id == session.kitID }) else { continue }
                    let step = kit.orderedActiveSteps.first { $0.id == session.stepID }
                    await NotificationService.shared.scheduleReminder(for: session, kitTitle: kit.title,
                                                                      stepTitle: step?.stepTitle)
                }
            }
        }
    }

    private var calendarList: some View {
        ScrollViewReader { proxy in
            List {
                monthSection
                daySection
                if !upcomingSessions.isEmpty {
                    Section {
                        NavigationLink(value: CalendarRoute.upcomingSessions) {
                            Label {
                                Text("Próximas sesiones (\(upcomingSessions.count))")
                            } icon: {
                                Image(systemName: Symbols.session).foregroundStyle(.tint)
                            }
                        }
                        .accessibilityIdentifier("calendar.upcomingSessions")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(alignment: .top) { BrandGlow() }
            .background(Color(.systemGroupedBackground))
            .onChange(of: selectedDate) { _, _ in
                // Solo se mueve si la agenda del día no se ve.
                guard !dayVisible else { return }
                withAnimation(reduceMotion ? nil : .smooth) {
                    proxy.scrollTo(Self.dayAnchor, anchor: .center)
                }
            }
        }
    }

    /// Sin Kits todavía: el calendario del sistema sigue visible y una tarjeta breve
    /// explica qué aparecerá en él (no repite la ilustración de Mis Kits).
    private var emptyCalendar: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        IconChip(symbol: Symbols.session, color: .accentColor, size: 40)
                        Text("Aún no hay nada planificado")
                            .font(.headline)
                    }
                    Text("Cuando crees un Kit verás aquí sus pasos sugeridos y su fecha prevista. También podrás reservar sesiones para avanzar.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button { showingKitCreator = true } label: {
                        Text("Crear un Kit").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                        .accessibilityIdentifier("calendar.createKit")
                }
                .padding(.vertical, 6)
            }
            Section("Qué verás aquí") {
                legendRow(symbol: "circle.fill", title: "Sesiones reservadas",
                          detail: "El tiempo que apartas para avanzar. Son tu compromiso.")
                legendRow(symbol: "circle", title: "Pasos sugeridos",
                          detail: "La fecha orientativa de cada paso.")
                legendRow(symbol: "flag.fill", title: "Fecha prevista", tint: .purple,
                          detail: "Cuándo terminaría el Kit según su plan.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(alignment: .top) { BrandGlow() }
        .background(Color(.systemGroupedBackground))
    }

    private func legendRow(symbol: String, title: String, tint: Color = .blue, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
                .frame(width: 24)
                .padding(.top, 2)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Secciones

    private var monthSection: some View {
        Section {
            DecoratedCalendarView(selectedDate: $selectedDate, marks: marks, revealToken: revealToken)
                .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
        } header: {
            // Leyenda en la cabecera: siempre legible, sin ocupar una fila propia.
            HStack(spacing: 10) { legend }
                .font(.caption)
                .textCase(nil)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Leyenda: punto, sesión reservada; círculo, paso sugerido; bandera, fecha prevista")
        }
    }

    @ViewBuilder
    private var daySection: some View {
        let empty = sessionsForSelectedDate.isEmpty && stepsForSelectedDate.isEmpty && goalsForSelectedDate.isEmpty
        Section {
            Text(daySummary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .id(Self.dayAnchor)
                .onScrollVisibilityChange(threshold: 0.5) { dayVisible = $0 }
                .accessibilityIdentifier("calendar.daySummary")
            if empty, !selectedDayIsPast, !activeKits.isEmpty {
                Button("Reservar sesión este día", systemImage: Symbols.session) { showingBookSession = true }
                    .accessibilityIdentifier("calendar.bookDay")
            }
            ForEach(sessionsForSelectedDate) { session in
                Button { reviewingSession = session } label: {
                    dayRow(symbol: "circle.fill", tint: .blue,
                           title: sessionTitle(session),
                           detail: "\(session.startsAt.formatted(date: .omitted, time: .shortened)) · \(session.durationMinutes) min · Sesión")
                }
                .buttonStyle(.plain)
            }
            ForEach(stepsForSelectedDate) { step in
                NavigationLink(value: StepNavigation(id: step.id)) {
                    dayRow(symbol: step.isCompleted ? "checkmark.circle.fill" : "circle",
                           tint: step.isCompleted ? .green : .blue,
                           title: step.stepTitle,
                           detail: "\(step.goal?.title ?? "") · Paso sugerido")
                }
            }
            ForEach(goalsForSelectedDate) { kit in
                NavigationLink(value: GoalNavigation(id: kit.id)) {
                    dayRow(symbol: "flag.fill", tint: .purple, title: kit.title, detail: "Fecha prevista")
                }
            }
        } header: {
            Text(selectedDate.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(.headline)
                .foregroundStyle(Color(.label))
                .textCase(nil)
        }
    }

    @ViewBuilder private var legend: some View {
        Label("Sesión", systemImage: "circle.fill").foregroundStyle(.blue).fixedSize()
        Label("Sugerencia", systemImage: "circle").foregroundStyle(.blue).fixedSize()
        Label("Fecha prevista", systemImage: "flag.fill").foregroundStyle(.purple).fixedSize()
    }

    // MARK: - Resumen del día

    /// «2 sesiones · 45 min reservados · 1 paso sugerido», o «Nada previsto este día».
    private var daySummary: String {
        var parts: [String] = []
        let daySessions = sessionsForSelectedDate
        if !daySessions.isEmpty {
            let count = daySessions.count
            parts.append(count == 1 ? "1 sesión" : "\(count) sesiones")
            parts.append("\(Self.duration(daySessions.reduce(0) { $0 + $1.durationMinutes })) reservados")
        }
        let steps = stepsForSelectedDate.count
        if steps > 0 {
            parts.append(steps == 1 ? "1 paso sugerido" : "\(steps) pasos sugeridos")
        }
        let kits = goalsForSelectedDate.count
        if kits > 0 {
            parts.append(kits == 1 ? "1 fecha prevista" : "\(kits) fechas previstas")
        }
        return parts.isEmpty ? "Nada previsto este día." : parts.joined(separator: " · ")
    }

    private static func duration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let rest = minutes % 60
        if hours == 0 { return "\(rest) min" }
        return rest == 0 ? "\(hours) h" : "\(hours) h \(rest) min"
    }

    // MARK: - Filas

    private func sessionTitle(_ session: WorkSessionEntity) -> String {
        let kit = visibleGoalEntities.first { $0.id == session.kitID }
        if let step = kit?.orderedActiveSteps.first(where: { $0.id == session.stepID }) {
            return step.stepTitle
        }
        return kit?.title ?? "Sesión"
    }

    private func dayRow(symbol: String, tint: Color, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).foregroundStyle(tint).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    CalendarPlusView()
}
