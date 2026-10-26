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
    @Environment(AuthManager.self) private var authManager
    @Query(filter: #Predicate<GoalEntity> { !$0.isDeleted },
           sort: \GoalEntity.createdAt,
           order: .reverse)
    private var goalEntities: [GoalEntity]
    @Query(sort: \WorkSessionEntity.startsAt) private var allSessions: [WorkSessionEntity]

    @State private var selectedDate: Date = Date()
    @State private var detailToken = 0
    @State private var sideBySide = false
    @State private var revealToken = 0
    @State private var dayVisible = true
    @State private var showingKitCreator = false
    @State private var booking: SessionBookingKind?
    @State private var reviewingSession: WorkSessionEntity?
    @State private var navigationPath = NavigationPath()


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
        return allSessions.filter {
            $0.ownerID == ownerID && $0.deletedAt == nil && ($0.isFree || kitIDs.contains($0.kitID))
        }
    }

    private var upcomingSessions: [WorkSessionEntity] {
        let now = Date()
        return sessions.filter { $0.endsAt >= now }
    }

    private var marks: [DateComponents: [CalendarMark: Int]] {
        var result: [DateComponents: [CalendarMark: Int]] = [:]
        func add(_ date: Date, _ mark: CalendarMark) {
            result[DateComponents.day(of: date), default: [:]][mark, default: 0] += 1
        }
        for kit in activeKits {
            for step in kit.orderedActiveSteps where !step.isCompleted {
                // Un paso que se repite marca cada una de sus sesiones.
                for date in step.sessionDates { add(date, .suggestion) }
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
                step.sessionDates.contains { Calendar.current.isDate($0, inSameDayAs: selectedDate) }
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
                // «Hoy» solo cuando te has movido a otro día y hay algo planificado.
                if !Calendar.current.isDateInToday(selectedDate), !marks.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Hoy") {
                            selectedDate = Date()
                            revealToken += 1
                        }
                        .accessibilityIdentifier("calendar.today")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        bookingButtons
                        Divider()
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
            .sheet(item: $booking) { kind in
                switch kind {
                case .free:
                    if let ownerID { BookFreeSessionSheet(ownerID: ownerID, initialDate: selectedDate) }
                case .kit:
                    BookSessionSheet(kits: activeKits, initialDate: selectedDate)
                }
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

    @ViewBuilder private var calendarList: some View {
        if sideBySide {
            // Pantalla ancha y baja (iPhone Duo abierto en horizontal, iPad): el mes a la izquierda
            // y el día elegido a la derecha, a la vista sin desplazarse.
            // Separación clara entre el mes y el día, sin recortar ninguna de las dos columnas.
            HStack(alignment: .top, spacing: 16) {
                List { monthSection }
                    .frame(maxWidth: 500)
                List {
                    daySection
                    upcomingSection
                }
            }
            .scrollContentBackground(.hidden)
            .background(alignment: .top) { BrandGlow() }
            .background(Color(.systemGroupedBackground))
            .onGeometryChange(for: Bool.self, of: isSideBySide) { sideBySide = $0 }
        } else {
            stackedList
        }
    }

    /// Ancho y bajo: el calendario y su detalle no caben uno sobre otro.
    private func isSideBySide(_ proxy: GeometryProxy) -> Bool {
        proxy.size.width >= 760 && proxy.size.width > proxy.size.height
    }

    /// Dos formas de reservar: un rato para algo propio o tiempo para un paso de un Kit.
    @ViewBuilder private var bookingButtons: some View {
        Button("Algo propio", systemImage: "person.crop.circle.badge.clock") { booking = .free }
            .accessibilityIdentifier("calendar.bookFree")
        Button("Sesión de un Kit", systemImage: Symbols.kits) { booking = .kit }
            .disabled(activeKits.isEmpty)
            .accessibilityIdentifier("calendar.bookKit")
    }

    @ViewBuilder private var upcomingSection: some View {
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

    private var stackedList: some View {
        List {
            monthSection
            daySection
            upcomingSection
        }
        .scrollContentBackground(.hidden)
        .background(alignment: .top) { BrandGlow() }
        .background(Color(.systemGroupedBackground))
        .onGeometryChange(for: Bool.self, of: isSideBySide) { sideBySide = $0 }
        .onChange(of: selectedDate) { _, _ in
            // Al tocar un día con cosas que hacer, la lista baja con suavidad hasta su detalle.
            guard !(sessionsForSelectedDate.isEmpty && stepsForSelectedDate.isEmpty && goalsForSelectedDate.isEmpty)
            else { return }
            detailToken += 1
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
            DecoratedCalendarView(selectedDate: $selectedDate, marks: marks, revealToken: revealToken, detailToken: detailToken)
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
                .onScrollVisibilityChange(threshold: 0.5) { dayVisible = $0 }
                .accessibilityIdentifier("calendar.daySummary")
            if empty, !selectedDayIsPast {
                Menu {
                    bookingButtons
                } label: {
                    Label("Reservar este día", systemImage: Symbols.session)
                }
                .accessibilityIdentifier("calendar.bookDay")
            }
            ForEach(sessionsForSelectedDate) { session in
                Button { reviewingSession = session } label: {
                    dayRow(symbol: session.isFree ? "circle.fill" : "circle.fill", tint: session.isFree ? .teal : .blue,
                           title: sessionTitle(session),
                           detail: "\(session.startsAt.formatted(date: .omitted, time: .shortened)) · \(session.durationMinutes) min · \(session.isFree ? "Algo propio" : "Sesión")")
                }
                .buttonStyle(.plain)
            }
            ForEach(stepsForSelectedDate) { step in
                NavigationLink(value: StepNavigation(id: step.id)) {
                    dayRow(symbol: step.isCompleted ? "checkmark.circle.fill" : "circle",
                           tint: step.isCompleted ? .green : .blue,
                           title: step.stepTitle,
                           detail: stepDayDetail(step))
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
        if session.isFree { return session.title ?? "Sesión propia" }
        let kit = visibleGoalEntities.first { $0.id == session.kitID }
        if let step = kit?.orderedActiveSteps.first(where: { $0.id == session.stepID }) {
            return step.stepTitle
        }
        return kit?.title ?? "Sesión"
    }

    /// «Kit · Paso sugerido», o «Kit · Día 3 de 14» si el paso se repite.
    private func stepDayDetail(_ step: StepEntity) -> String {
        let kit = step.goal?.title ?? ""
        guard let repetition = step.repetition,
              let index = step.sessionDates.firstIndex(where: { Calendar.current.isDate($0, inSameDayAs: selectedDate) })
        else { return "\(kit) · Paso sugerido" }
        return "\(kit) · \(repetition.sessionName(index))"
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
