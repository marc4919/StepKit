//
//  KitAssistantModel.swift
//  StepKit
//
//  Un único asistente que pertenece al Kit. Conversaciones por asunto: las que se
//  abren desde un paso quedan vinculadas a él. Desde un paso no se cambia el resto
//  del Kit sin una propuesta que el usuario acepta o descarta entera.
//  Las conversaciones viven en memoria (todavía sin persistencia ni sync).
//

import SwiftUI
import SwiftData

@MainActor
@Observable
final class KitConversation: Identifiable {
    let id = UUID()
    let kitID: UUID
    /// Paso al que pertenece la conversación, si se abrió desde un paso.
    let stepID: UUID?
    var title: String
    let createdAt = Date()
    let viewModel = TrainerViewModel()
    var proposals: [PlanProposal] = []
    /// Resumen que devuelve el asistente del servidor; se manda en la siguiente llamada.
    var serverSummary: String?

    init(kitID: UUID, stepID: UUID?, title: String) {
        self.kitID = kitID
        self.stepID = stepID
        self.title = title
    }

    var lastActivity: Date { viewModel.messages.last?.timestamp ?? createdAt }
    var preview: String? { viewModel.messages.last(where: { $0.sender == .assistant && !$0.isError })?.text }
}

@MainActor
@Observable
final class KitAssistantStore {
    static let shared = KitAssistantStore()

    private(set) var conversations: [KitConversation] = []

    func conversations(for kitID: UUID) -> [KitConversation] {
        conversations.filter { $0.kitID == kitID }.sorted { $0.lastActivity > $1.lastActivity }
    }

    /// Conversación vigente del paso o una nueva vinculada a él.
    func conversation(kit: GoalEntity, step: StepEntity) -> KitConversation {
        if let existing = conversations.first(where: { $0.stepID == step.id }) {
            return existing
        }
        let created = KitConversation(kitID: kit.id, stepID: step.id,
                                      title: "Paso \(kit.position(of: step)) · \(step.stepTitle)")
        conversations.append(created)
        return created
    }

    func newConversation(kit: GoalEntity, title: String) -> KitConversation {
        let created = KitConversation(kitID: kit.id, stepID: nil, title: title)
        conversations.append(created)
        return created
    }

    #if DEBUG
    func removeAll() { conversations.removeAll() }
    #endif
}

// MARK: - Propuestas

/// Un cambio concreto: de fecha (from → to) o de contenido (detail).
struct ProposedStepChange: Identifiable, Hashable {
    let id = UUID()
    let stepID: UUID?
    let stepLabel: String
    let from: Date?
    let to: Date?
    var detail: String? = nil
    var symbol: String = Symbols.calendar
}

/// Conjunto coherente de cambios: se acepta o se descarta entero, sin selección parcial.
@MainActor
@Observable
final class PlanProposal: Identifiable {
    enum State { case pending, accepted, discarded }

    enum Action {
        case setDate(stepID: UUID, date: Date)
        case edit(stepID: UUID, title: String?, minutes: Int?)
        case split(stepID: UUID, titles: [String], minutes: Int?)
        /// `afterStepID` nil y `atStart` true: al principio; nil y false: al final.
        case add(afterStepID: UUID?, atStart: Bool, title: String, minutes: Int, date: Date?)
        case remove(stepID: UUID)
        case block(stepID: UUID, reason: String)
    }

    let id = UUID()
    let title: String
    let changes: [ProposedStepChange]
    let impact: String
    let actions: [Action]
    var state: State = .pending

    init(title: String, changes: [ProposedStepChange], impact: String, actions: [Action]? = nil) {
        self.title = title
        self.changes = changes
        self.impact = impact
        self.actions = actions ?? changes.compactMap { change in
            guard let stepID = change.stepID, let to = change.to else { return nil }
            return .setDate(stepID: stepID, date: to)
        }
    }

    func accept(in kit: GoalEntity, context: ModelContext) {
        let now = Date()
        func step(_ id: UUID) -> StepEntity? { kit.orderedActiveSteps.first { $0.id == id } }
        func insert(_ title: String, minutes: Int, date: Date?, after anchor: StepEntity?, atStart: Bool = false) {
            let order = atStart ? (kit.orderedActiveSteps.first?.order ?? 0)
                : (anchor?.order ?? (kit.orderedActiveSteps.last?.order ?? -1)) + 1
            let new = StepEntity(ownerID: kit.ownerID, stepTitle: title, descriptionShort: "", descriptionLong: "",
                                 estimateMinutes: minutes, suggestedDeadline: date ?? anchor?.suggestedDeadline,
                                 effortLevel: anchor?.effortLevel ?? "medium",
                                 order: order,
                                 createdAt: now, updatedAt: now)
            // Hace hueco detrás del paso de referencia.
            for later in kit.orderedActiveSteps where later.order >= new.order {
                later.order += 1
                later.markModified(at: now)
            }
            new.goal = kit
            context.insert(new)
            kit.steps.append(new)
        }
        for action in actions {
            switch action {
            case .setDate(let id, let date):
                step(id)?.suggestedDeadline = date
                step(id)?.markModified(at: now)
            case .edit(let id, let title, let minutes):
                guard let target = step(id) else { continue }
                if let title { target.stepTitle = title }
                if let minutes { target.estimateMinutes = minutes }
                target.markModified(at: now)
            case .split(let id, let titles, let minutes):
                guard let target = step(id), let first = titles.first else { continue }
                target.stepTitle = first
                // Dividir sirve para seguir avanzando: la primera parte deja de estar bloqueada.
                target.blockedReason = nil
                target.blockedAt = nil
                if let minutes { target.estimateMinutes = minutes }
                target.markModified(at: now)
                var anchor = target
                for title in titles.dropFirst() {
                    insert(title, minutes: minutes ?? target.estimateMinutes, date: target.suggestedDeadline, after: anchor)
                    if let added = kit.orderedActiveSteps.first(where: { $0.order == anchor.order + 1 }) { anchor = added }
                }
            case .add(let afterID, let atStart, let title, let minutes, let date):
                insert(title, minutes: minutes, date: date, after: afterID.flatMap(step), atStart: atStart)
            case .remove(let id):
                guard let target = step(id) else { continue }
                target.deletedAt = now
                target.markModified(at: now)
            case .block(let id, let reason):
                guard let target = step(id) else { continue }
                target.blockedReason = reason
                target.blockedAt = now
                target.markModified(at: now)
            }
        }
        kit.markModified(at: now)
        try? context.save()
        state = .accepted
    }
}

/// Propuestas deterministas que StepKit prepara sin IA: mover fechas respetando el orden.
@MainActor
enum PlanProposalBuilder {
    private static let calendar = Calendar.current

    private static func day(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.wide))
    }

    /// Mueve el paso unos días y desplaza los siguientes que quedarían antes de él.
    static func moveStep(_ step: StepEntity, in kit: GoalEntity, byDays days: Int = 5) -> PlanProposal? {
        let steps = kit.orderedActiveSteps.filter { !$0.isCompleted }
        guard let index = steps.firstIndex(where: { $0.id == step.id }),
              let current = step.suggestedDeadline,
              let moved = calendar.date(byAdding: .day, value: days, to: current) else { return nil }
        var changes = [ProposedStepChange(stepID: step.id, stepLabel: "Paso \(kit.position(of: step)) · \(step.stepTitle)",
                                          from: current, to: moved)]
        var previous = moved
        for next in steps.dropFirst(index + 1) {
            guard let date = next.suggestedDeadline, date <= previous,
                  let shifted = calendar.date(byAdding: .day, value: 2, to: previous) else { break }
            changes.append(ProposedStepChange(stepID: next.id, stepLabel: "Paso \(kit.position(of: next)) · \(next.stepTitle)",
                                              from: date, to: shifted))
            previous = shifted
        }
        let impact: String
        if changes.count > 1, let last = changes.last {
            impact = "Para mantener el orden, «\(last.stepLabel.components(separatedBy: " · ").last ?? "")» pasa al \(last.to.map(day) ?? ""). El resto del plan no cambia."
        } else {
            impact = "Solo cambia este paso. El resto del plan sigue igual."
        }
        return PlanProposal(title: "Mover el paso \(kit.position(of: step)) al \(day(moved))",
                            changes: changes, impact: impact)
    }

    /// Retrasa la fecha deseada desplazando todos los pasos pendientes.
    static func shiftTarget(of kit: GoalEntity, byDays days: Int = 7) -> PlanProposal? {
        let pending = kit.orderedActiveSteps.filter { !$0.isCompleted && $0.suggestedDeadline != nil }
        guard !pending.isEmpty else { return nil }
        let changes = pending.compactMap { step -> ProposedStepChange? in
            guard let date = step.suggestedDeadline,
                  let shifted = calendar.date(byAdding: .day, value: days, to: date) else { return nil }
            return ProposedStepChange(stepID: step.id, stepLabel: "Paso \(kit.position(of: step)) · \(step.stepTitle)",
                                      from: date, to: shifted)
        }
        let newTarget = changes.compactMap(\.to).max().map(day) ?? ""
        return PlanProposal(title: "Retrasar la fecha deseada una semana", changes: changes,
                            impact: "La fecha deseada pasa al \(newTarget). Cada paso pendiente se mueve \(days) días.")
    }
}
