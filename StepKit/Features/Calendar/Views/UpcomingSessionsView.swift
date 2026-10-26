//
//  UpcomingSessionsView.swift
//  StepKit
//
//  Todas las sesiones reservadas que aún no han terminado, en línea de tiempo.
//  Se abre desde la fila «Próximas sesiones (N)» al final de la agenda del día.
//

import SwiftUI

struct UpcomingSessionsView: View {
    let sessions: [WorkSessionEntity]
    let kits: [GoalEntity]

    @State private var reviewingSession: WorkSessionEntity?

    var body: some View {
        List {
            ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                sessionRow(session, last: index == sessions.count - 1)
            }
        }
        .overlay {
            if sessions.isEmpty {
                ContentUnavailableView("No tienes nada reservado", systemImage: Symbols.session)
            }
        }
        .navigationTitle("Tiempo reservado")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $reviewingSession) { session in
            let kit = kits.first { $0.id == session.kitID }
            ReviewSessionSheet(session: session, kit: kit,
                               step: kit?.orderedActiveSteps.first { $0.id == session.stepID })
        }
    }

    private func sessionRow(_ session: WorkSessionEntity, last: Bool) -> some View {
        let kit = kits.first { $0.id == session.kitID }
        let step = kit?.orderedActiveSteps.first { $0.id == session.stepID }
        let label = HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                // Mismo código de color que el calendario: azul para un Kit, verde azulado para algo propio.
                Circle().fill(session.isFree ? Color.teal : Color.accentColor).frame(width: 12, height: 12).padding(.top, 5)
                if !last {
                    Rectangle().fill(Color.accentColor.opacity(0.3)).frame(width: 2).frame(maxHeight: .infinity)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.when(session)).font(.subheadline.weight(.semibold)).foregroundStyle(.tint)
                Text(Self.title(session, kit: kit, step: step)).font(.headline)
                Text(Self.detail(session, kit: kit, step: step)).font(.subheadline).foregroundStyle(.secondary)
            }
            .padding(.bottom, last ? 0 : 12)
        }
        .accessibilityElement(children: .combine)

        return Group {
            if let step {
                NavigationLink(value: StepNavigation(id: step.id)) { label }
            } else {
                Button { reviewingSession = session } label: { label }
                    .buttonStyle(.plain)
            }
        }
        .listRowSeparator(.hidden)
        .swipeActions {
            Button("Revisar", systemImage: Symbols.session) { reviewingSession = session }
                .tint(.blue)
        }
        .contextMenu {
            Button("Revisar sesión", systemImage: Symbols.session) { reviewingSession = session }
        }
    }

    static func when(_ session: WorkSessionEntity) -> String {
        let time = session.startsAt.formatted(date: .omitted, time: .shortened)
        if Calendar.current.isDateInToday(session.startsAt) { return String(localized: "Hoy · \(time)") }
        if Calendar.current.isDateInTomorrow(session.startsAt) { return String(localized: "Mañana · \(time)") }
        return "\(session.startsAt.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))) · \(time)"
    }

    /// Lo que se va a hacer: el paso, el Kit o, si es algo propio, lo que escribiste al reservarlo.
    static func title(_ session: WorkSessionEntity, kit: GoalEntity?, step: StepEntity?) -> String {
        if session.isFree, let title = session.title, !title.isEmpty { return title }
        return step?.stepTitle ?? kit?.title ?? String(localized: "Algo propio")
    }

    static func detail(_ session: WorkSessionEntity, kit: GoalEntity?, step: StepEntity?) -> String {
        var parts = [String(localized: "\(session.durationMinutes) min")]
        if session.isFree { parts.append(String(localized: "Algo propio")) }
        if let kit { parts.append(kit.title) }
        if let kit, let step { parts.append(String(localized: "Paso \(kit.position(of: step))")) }
        return parts.joined(separator: " · ")
    }
}
