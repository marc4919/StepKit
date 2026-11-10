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
    /// El asistente propone otro Kit en vez de cambiar este: la conversación ofrece crearlo.
    var newKitSuggestion: AssistResponse.Suggestion?
    /// Qué se cambió a mano en el plan, para la revisión que se ofrece al guardar.
    var planChanges: String?

    init(kitID: UUID, stepID: UUID?, title: String) {
        self.kitID = kitID
        self.stepID = stepID
        self.title = title
    }

    var lastActivity: Date { viewModel.messages.last?.timestamp ?? createdAt }

    /// Propuestas pendientes de decidir en esta conversación.
    var pendingProposalCount: Int { proposals.filter { $0.state == .pending }.count }

    /// La misma propuesta que la persona ya descartó: no se le vuelve a enseñar.
    func wasDiscarded(_ proposal: PlanProposal) -> Bool {
        proposals.contains { $0.state == .discarded && $0.contentSignature == proposal.contentSignature }
    }

    /// Añade una propuesta en su sitio de la conversación (tras el mensaje que la acompaña).
    /// Una propuesta nueva sustituye a las pendientes anteriores: así no se solapan cambios contradictorios.
    func add(_ proposal: PlanProposal) {
        for old in proposals where old.state == .pending { old.state = .superseded }
        proposal.anchorMessageID = viewModel.messages.last?.id
        proposals.append(proposal)
    }
    /// El cupo mensual de IA se agotó al preguntar: se ofrece Pro en lugar de un error.
    var quotaReached = false
    var preview: String? { viewModel.messages.last(where: { $0.sender == .assistant && !$0.isError })?.text }
    /// Lo último que pidió la persona: en el historial dice de qué va la conversación mejor que el nombre del paso.
    var lastAsk: String? {
        viewModel.messages.last(where: { $0.sender == .user })?.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Pasos que el asistente acaba de tocar: el plan los resalta unos segundos cuando vuelve a verse,
/// con una etiqueta que dice qué pasó (editado, nuevo, movido, en pausa).
@MainActor
@Observable
final class ChangeHighlights {
    enum Kind { case edited, added, moved, blocked }

    private(set) var kinds: [UUID: Kind] = [:]
    private var fadeTask: Task<Void, Never>?

    func record(_ kind: Kind, for stepID: UUID) {
        fadeTask?.cancel()
        kinds[stepID] = kind
    }

    func kind(for stepID: UUID) -> Kind? { kinds[stepID] }

    /// Cuando el plan vuelve a estar a la vista: unos segundos resaltados y después se apagan.
    func fade(after seconds: Double = 3) {
        guard !kinds.isEmpty else { return }
        fadeTask?.cancel()
        fadeTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.8)) { kinds.removeAll() }
        }
    }
}

@MainActor
@Observable
final class KitAssistantStore {
    static let shared = KitAssistantStore()
    let highlights = ChangeHighlights()

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
                                      title: String(localized: "Paso \(kit.position(of: step)) · \(step.stepTitle)"))
        conversations.append(created)
        return created
    }

    func newConversation(kit: GoalEntity, title: String) -> KitConversation {
        let created = KitConversation(kitID: kit.id, stepID: nil, title: title)
        conversations.append(created)
        return created
    }

    /// Al cerrar sesión o borrar la cuenta (y en las demos): no queda ninguna conversación en memoria.
    func removeAll() { conversations.removeAll() }
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
    /// División de un paso: los títulos de las partes, en orden. Se muestran como lista numerada.
    var parts: [String] = []
    /// Texto para «Tu recorrido», más corto que `detail` cuando el detalle ya se ve en el plan.
    var logDetail: String? = nil
    /// Tras aplicar una división: la primera parte (el paso original) y las nuevas, para abrir cada una.
    var partStepIDs: [UUID] = []
}

/// Conjunto coherente de cambios: se acepta o se descarta entero, sin selección parcial.
@MainActor
@Observable
final class PlanProposal: Identifiable {
    enum State { case pending, accepted, discarded, superseded }

    enum Action {
        case setDate(stepID: UUID, date: Date)
        case edit(stepID: UUID, title: String?, minutes: Int?, outcome: String? = nil, description: String? = nil)
        /// `outcomes` y `descriptions`, una entrada por parte; sin ellas, las partes heredan los textos del paso.
        case split(stepID: UUID, titles: [String], minutes: Int?, outcomes: [String]? = nil, descriptions: [String]? = nil)
        /// `afterStepID` nil y `atStart` true: al principio; nil y false: al final.
        case add(afterStepID: UUID?, atStart: Bool, title: String, minutes: Int, date: Date?, outcome: String?, description: String?)
        case remove(stepID: UUID)
        /// Deja el plan en `order`; se repite con cada paso movido para marcarlos de uno en uno en la tarjeta.
        case reorder(order: [UUID], movedStepID: UUID)
        case block(stepID: UUID, reason: String)
        case changeKPI(String)
        /// Nueva fecha final del Kit (los pasos se mueven con `setDate`).
        case setKitDueDate(Date)
    }

    let id = UUID()
    let title: String
    private(set) var changes: [ProposedStepChange]
    let impact: String
    let actions: [Action]
    var state: State = .pending
    /// Mensaje tras el que se muestra la propuesta dentro de la conversación.
    var anchorMessageID: UUID?

    init(title: String, changes: [ProposedStepChange], impact: String, actions: [Action]? = nil) {
        self.title = title
        self.changes = changes
        self.impact = impact
        self.actions = actions ?? changes.compactMap { change in
            guard let stepID = change.stepID, let to = change.to else { return nil }
            return .setDate(stepID: stepID, date: to)
        }
    }

    /// Lo que cambia de verdad, sin el texto del modelo: dos propuestas con el mismo contenido
    /// son la misma aunque se redacten distinto. Las fechas cuentan por días.
    var contentSignature: Set<String> {
        func day(_ date: Date?) -> String {
            date.map { Calendar.current.dateComponents([.year, .month, .day], from: $0).description } ?? ""
        }
        func text(_ value: String?) -> String { (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        return Set(actions.map { action in
            switch action {
            case .setDate(let id, let date): "date|\(id)|\(day(date))"
            case .edit(let id, let title, let minutes, _, _): "edit|\(id)|\(text(title))|\(minutes ?? 0)"
            case .split(let id, let titles, _, _, _): "split|\(id)|\(titles.map { text($0) })"
            case .add(_, _, let title, _, let date, _, _): "add|\(text(title))|\(day(date))"
            case .remove(let id): "remove|\(id)"
            case .reorder(let order, _): "reorder|\(order)"
            case .block(let id, _): "block|\(id)"
            case .changeKPI(let kpi): "kpi|\(text(kpi))"
            case .setKitDueDate(let date): "due|\(day(date))"
            }
        })
    }

    /// Cambios de esta propuesta ya aplicados: la tarjeta les pone el check de uno en uno.
    var appliedChangeIDs: Set<UUID> = []
    /// Aplicándose: los botones de aceptar y descartar desaparecen mientras tanto.
    var applying = false

    /// Aplica los cambios de uno en uno, con animación y una pausa breve entre ellos, para que se vea
    /// qué se altera, se recorta o se añade. Cada paso tocado queda marcado en el plan (`ChangeHighlights`).
    /// `pause` y `animation` permiten otro ritmo cuando los pasos entran a la vista en el plan del Kit.
    func accept(in kit: GoalEntity, context: ModelContext, highlights: ChangeHighlights,
                pause: Duration = .milliseconds(450), animation: Animation? = .smooth(duration: 0.45)) async {
        guard !applying, state == .pending else { return }
        applying = true
        let now = Date()
        let paired = actions.count == changes.count
        for (index, action) in actions.enumerated() {
            withAnimation(animation) {
                splitParts = []
                apply(action, in: kit, context: context, now: now, highlights: highlights)
                if paired {
                    appliedChangeIDs.insert(changes[index].id)
                    if case .split = action { changes[index].partStepIDs = splitParts }
                }
            }
            if index < actions.count - 1 {
                try? await Task.sleep(for: pause)
            }
        }
        kit.markModified(at: now)
        try? context.save()
        withAnimation(.default) {
            appliedChangeIDs.formUnion(changes.map(\.id))
            state = .accepted
        }
        applying = false
    }

    /// Pasos que dejó la última división aplicada, en orden.
    private var splitParts: [UUID] = []

    private func apply(_ action: Action, in kit: GoalEntity, context: ModelContext, now: Date,
                       highlights: ChangeHighlights) {
        func step(_ id: UUID) -> StepEntity? { kit.orderedActiveSteps.first { $0.id == id } }
        @discardableResult
        func insert(_ title: String, minutes: Int, date: Date?, after anchor: StepEntity?, atStart: Bool = false,
                    short: String = "", long: String = "") -> StepEntity {
            let new = StepListEditor.insert(title: title, minutes: minutes, date: date, after: anchor, atStart: atStart,
                                            short: short, long: long, into: kit, context: context, at: now)
            highlights.record(.added, for: new.id)
            return new
        }
        switch action {
        case .setDate(let id, let date):
            guard let target = step(id) else { return }
            target.suggestedDeadline = date
            target.markModified(at: now)
            highlights.record(.moved, for: target.id)
        case .edit(let id, let title, let minutes, let outcome, let description):
            guard let target = step(id) else { return }
            if let title { target.stepTitle = title }
            if let minutes { target.estimateMinutes = minutes }
            // Si cambia de qué va el paso, también su «Al terminar» y su descripción.
            if let outcome, !outcome.isEmpty { target.descriptionShort = outcome }
            if let description, !description.isEmpty { target.descriptionLong = description }
            // Si el paso se reescribe, lo que lo frenaba ya no aplica; cambiar solo los minutos no lo resuelve.
            if title != nil || outcome?.isEmpty == false || description?.isEmpty == false {
                target.blockedReason = nil
                target.blockedAt = nil
            }
            target.markModified(at: now)
            highlights.record(.edited, for: target.id)
        case .split(let id, let titles, let minutes, let outcomes, let descriptions):
            guard let target = step(id), let first = titles.first else { return }
            target.stepTitle = first
            // Con textos propios por parte, el paso original pasa a ser solo la primera parte.
            let ownTexts = outcomes?.count == titles.count && descriptions?.count == titles.count
            if ownTexts, let outcome = outcomes?.first, let description = descriptions?.first {
                target.descriptionShort = outcome
                target.descriptionLong = description
            }
            // Dividir sirve para seguir avanzando: la primera parte deja de estar bloqueada.
            target.blockedReason = nil
            target.blockedAt = nil
            if let minutes { target.estimateMinutes = minutes }
            target.markModified(at: now)
            highlights.record(.edited, for: target.id)
            splitParts = [target.id]
            var anchor = target
            // Las partes nuevas heredan la descripción del paso original para no quedar vacías.
            let original = target.descriptionLong.isEmpty ? target.descriptionShort : target.descriptionLong
            for (offset, title) in titles.dropFirst().enumerated() {
                // Las partes van el mismo día que el paso: dividir no alarga el plan ni se sale de la fecha final.
                let short = ownTexts ? outcomes?[offset + 1] ?? "" : String(localized: "Parte de «\(first)». \(target.descriptionShort)").trimmingCharacters(in: .whitespaces)
                let long = ownTexts ? descriptions?[offset + 1] ?? "" : original
                anchor = insert(title, minutes: minutes ?? target.estimateMinutes, date: target.suggestedDeadline, after: anchor,
                                short: short, long: long)
                splitParts.append(anchor.id)
            }
        case .add(let afterID, let atStart, let title, let minutes, let date, let outcome, let description):
            insert(title, minutes: minutes, date: date, after: afterID.flatMap(step), atStart: atStart,
                   short: outcome ?? "", long: description ?? "")
        case .remove(let id):
            guard let target = step(id) else { return }
            let detached = StepListEditor.remove(target, from: kit, context: context, at: now)
            StepListEditor.refreshReminders(of: detached, kit: kit)
        case .reorder(let order, let moved):
            StepListEditor.setOrder(order, of: kit, at: now)
            highlights.record(.moved, for: moved)
        case .changeKPI(let kpi):
            kit.kpi = kpi
            kit.markModified(at: now)
        case .setKitDueDate(let date):
            kit.targetDate = Calendar.current.startOfDay(for: date)
            kit.markModified(at: now)
        case .block(let id, let reason):
            guard let target = step(id) else { return }
            target.blockedReason = reason
            target.blockedAt = now
            target.markModified(at: now)
            highlights.record(.blocked, for: target.id)
        }
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
        var changes = [ProposedStepChange(stepID: step.id, stepLabel: String(localized: "Paso \(kit.position(of: step)) · \(step.stepTitle)"),
                                          from: current, to: moved)]
        var previous = moved
        for next in steps.dropFirst(index + 1) {
            guard let date = next.suggestedDeadline, date <= previous,
                  let shifted = calendar.date(byAdding: .day, value: 2, to: previous) else { break }
            changes.append(ProposedStepChange(stepID: next.id, stepLabel: String(localized: "Paso \(kit.position(of: next)) · \(next.stepTitle)"),
                                              from: date, to: shifted))
            previous = shifted
        }
        let impact: String
        if changes.count > 1, let last = changes.last {
            impact = String(localized: "Para mantener el orden, «\(last.stepLabel.components(separatedBy: " · ").last ?? "")» pasa al \(last.to.map(day) ?? ""). El resto del plan no cambia.")
        } else {
            impact = String(localized: "Solo cambia este paso. El resto del plan sigue igual.")
        }
        return PlanProposal(title: String(localized: "Mover el paso \(kit.position(of: step)) al \(day(moved))"),
                            changes: changes, impact: impact)
    }

    /// Retrasa la fecha deseada desplazando todos los pasos pendientes.
    static func shiftTarget(of kit: GoalEntity, byDays days: Int = 7) -> PlanProposal? {
        let pending = kit.orderedActiveSteps.filter { !$0.isCompleted && $0.suggestedDeadline != nil }
        guard !pending.isEmpty else { return nil }
        let changes = pending.compactMap { step -> ProposedStepChange? in
            guard let date = step.suggestedDeadline,
                  let shifted = calendar.date(byAdding: .day, value: days, to: date) else { return nil }
            return ProposedStepChange(stepID: step.id, stepLabel: String(localized: "Paso \(kit.position(of: step)) · \(step.stepTitle)"),
                                      from: date, to: shifted)
        }
        let newTarget = changes.compactMap(\.to).max().map(day) ?? ""
        return PlanProposal(title: String(localized: "Retrasar la fecha final una semana"), changes: changes,
                            impact: String(localized: "La fecha final pasa al \(newTarget). Cada paso pendiente se mueve \(days) días."))
    }
}
