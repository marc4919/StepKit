//
//  CalendarPlusView.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on 7/12/25.
//
//  v4.4: próximas sesiones, fecha deseada, UICalendarView con leyenda y el día elegido.
//  Solo las sesiones reservadas son compromisos; sugerencias y fecha deseada orientan.
//

import SwiftUI
import SwiftData

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
    @State private var showingKitCreator = false
    @State private var showingBookSession = false
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
        return allSessions.filter { $0.ownerID == ownerID && $0.deletedAt == nil && kitIDs.contains($0.kitID) }
    }

    private var upcomingSessions: [WorkSessionEntity] {
        let now = Date()
        return Array(sessions.filter { $0.endsAt >= now }.prefix(5))
    }

    /// Kit con la fecha deseada más próxima que aún no ha pasado.
    private var nextWanted: (kit: GoalEntity, date: Date)? {
        let today = Calendar.current.startOfDay(for: Date())
        return activeKits
            .compactMap { kit in kit.dueDate.map { (kit, $0) } }
            .filter { $0.1 >= today }
            .min { $0.1 < $1.1 }
    }

    private var marks: [DateComponents: CalendarMark] {
        var result: [DateComponents: CalendarMark] = [:]
        func add(_ date: Date, _ mark: CalendarMark) {
            let key = DateComponents.day(of: date)
            result[key] = max(result[key] ?? mark, mark)
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

    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                upcomingSection
                if let wanted = nextWanted {
                    wantedSection(kit: wanted.kit, date: wanted.date)
                }
                monthSection
                daySection
                if !stepsForSelectedDate.isEmpty || !goalsForSelectedDate.isEmpty {
                    Section {
                        DayInsightView(selectedDate: selectedDate, steps: stepsForSelectedDate, goals: goalsForSelectedDate)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(alignment: .top) { BrandGlow() }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Calendario")
            .toolbar {
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
            .task(id: upcomingSessions.map(\.updatedAt)) {
                // Las sesiones pueden llegar por sync desde otro dispositivo.
                for session in upcomingSessions {
                    guard let kit = visibleGoalEntities.first(where: { $0.id == session.kitID }) else { continue }
                    let step = kit.orderedActiveSteps.first { $0.id == session.stepID }
                    await NotificationService.shared.scheduleReminder(for: session, kitTitle: kit.title,
                                                                      stepTitle: step?.stepTitle)
                }
            }
        }
    }

    // MARK: - Secciones

    private var upcomingSection: some View {
        Section {
            if upcomingSessions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No tienes sesiones reservadas").font(.headline)
                    Text("Reserva un rato para avanzar en un paso. Es un compromiso contigo, no completa el paso.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Reservar sesión", systemImage: Symbols.session) { showingBookSession = true }
                        .disabled(activeKits.isEmpty)
                        .padding(.top, 4)
                }
                .padding(.vertical, 4)
            } else {
                ForEach(Array(upcomingSessions.enumerated()), id: \.element.id) { index, session in
                    sessionRow(session, last: index == upcomingSessions.count - 1)
                }
            }
        } header: {
            Text("Próximas sesiones")
                .font(.title3.bold())
                .foregroundStyle(.primary)
                .textCase(nil)
        }
    }

    private func wantedSection(kit: GoalEntity, date: Date) -> some View {
        Section {
            Button {
                navigationPath.append(GoalNavigation(id: kit.id))
            } label: {
                HStack(spacing: 12) {
                    IconChip(symbol: "flag.fill", color: .purple)
                    VStack(alignment: .leading) {
                        Text("Fecha deseada · \(date.formatted(.dateTime.day().month(.abbreviated)))")
                            .font(.headline)
                            .foregroundStyle(.purple)
                        Text("\(kit.title) · orientativa, sin límite firme")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
            .listRowBackground(Color.purple.opacity(0.10))
        }
    }

    private var monthSection: some View {
        Section {
            DecoratedCalendarView(selectedDate: $selectedDate, marks: marks)
                .frame(minHeight: 380)
                .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
            ViewThatFits {
                HStack(spacing: 16) { legend }
                VStack(alignment: .leading, spacing: 6) { legend }
            }
            .font(.caption)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Leyenda: punto, sesión reservada; círculo, paso sugerido; bandera, fecha deseada")
        } header: {
            Text("Mes").textCase(nil)
        } footer: {
            Text("Solo las sesiones reservadas son compromisos. Las sugerencias y la fecha deseada son orientativas.")
        }
    }

    @ViewBuilder
    private var daySection: some View {
        let empty = sessionsForSelectedDate.isEmpty && stepsForSelectedDate.isEmpty && goalsForSelectedDate.isEmpty
        Section {
            if empty {
                Text("Nada previsto este día.")
                    .foregroundStyle(.secondary)
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
                    dayRow(symbol: "flag.fill", tint: .purple, title: kit.title, detail: "Fecha deseada")
                }
            }
        } header: {
            Text(selectedDate.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .textCase(nil)
        }
    }

    @ViewBuilder private var legend: some View {
        Label("Sesión", systemImage: "circle.fill").foregroundStyle(.blue).fixedSize()
        Label("Sugerencia", systemImage: "circle").foregroundStyle(.blue).fixedSize()
        Label("Fecha deseada", systemImage: "flag.fill").foregroundStyle(.purple).fixedSize()
    }

    // MARK: - Filas

    private func sessionTitle(_ session: WorkSessionEntity) -> String {
        let kit = visibleGoalEntities.first { $0.id == session.kitID }
        if let step = kit?.orderedActiveSteps.first(where: { $0.id == session.stepID }) {
            return step.stepTitle
        }
        return kit?.title ?? "Sesión"
    }

    private func sessionRow(_ session: WorkSessionEntity, last: Bool) -> some View {
        let kit = visibleGoalEntities.first { $0.id == session.kitID }
        let step = kit?.orderedActiveSteps.first { $0.id == session.stepID }
        return Button {
            if let step {
                navigationPath.append(StepNavigation(id: step.id))
            } else {
                reviewingSession = session
            }
        } label: {
            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 0) {
                    Circle().fill(Color.accentColor).frame(width: 12, height: 12).padding(.top, 5)
                    if !last {
                        Rectangle().fill(Color.accentColor.opacity(0.3)).frame(width: 2).frame(maxHeight: .infinity)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(sessionWhen(session)).font(.subheadline.weight(.semibold)).foregroundStyle(.tint)
                    Text(step?.stepTitle ?? kit?.title ?? "Sesión").font(.headline)
                    Text(sessionDetail(session, kit: kit, step: step)).font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(.bottom, last ? 0 : 12)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 20)
                    .accessibilityHidden(true)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .listRowSeparator(.hidden)
        .swipeActions {
            Button("Revisar", systemImage: "calendar.badge.clock") { reviewingSession = session }
                .tint(.blue)
        }
        .contextMenu {
            Button("Revisar sesión", systemImage: "calendar.badge.clock") { reviewingSession = session }
        }
    }

    private func sessionWhen(_ session: WorkSessionEntity) -> String {
        let time = session.startsAt.formatted(date: .omitted, time: .shortened)
        if Calendar.current.isDateInToday(session.startsAt) { return "Hoy · \(time)" }
        if Calendar.current.isDateInTomorrow(session.startsAt) { return "Mañana · \(time)" }
        return "\(session.startsAt.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))) · \(time)"
    }

    private func sessionDetail(_ session: WorkSessionEntity, kit: GoalEntity?, step: StepEntity?) -> String {
        var parts = ["\(session.durationMinutes) min"]
        if let kit { parts.append(kit.title) }
        if let kit, let step { parts.append("Paso \(kit.position(of: step))") }
        return parts.joined(separator: " · ")
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
