//
//  KitAssistRemote.swift
//  StepKit
//
//  Asistente del Kit en el servidor (POST /ai/assist). La app manda el Kit, el registro
//  reciente, cuánto tienes ocupado cada día y la conversación; recibe una respuesta y,
//  si hace falta, una propuesta. Las propuestas se aceptan enteras y el efecto dominó
//  sobre las fechas lo calcula la app, no la IA.
//

import Foundation
import SwiftData

// MARK: - Contrato

struct AssistRequest: Encodable {
    struct Kit: Encodable {
        let title: String
        let kpi: String
        let dueDate: String?
        let dailyAvailableTime: Int
        let maxStepsPerDay: Int
    }

    struct Step: Encodable {
        let number: Int
        let title: String
        let descriptionShort: String
        let estimateMinutes: Int
        let suggestedDeadline: String?
        let completed: Bool
        let blockedReason: String?
        let repeatEvery: String?
        let repeatTimes: Int?
        let sessionsDone: Int?
        /// Posición en el plan que preparó la IA (1 = el primero); sin ella, el paso se añadió después.
        let planPosition: Int?
    }

    struct LogEntry: Encodable {
        let stepNumber: Int?
        let kind: String
        let note: String
        let notedAt: Date
    }

    struct Message: Encodable {
        let role: String
        let text: String
    }

    struct Conversation: Encodable {
        let summary: String?
        let messages: [Message]
    }

    let today: String
    let timezone: String
    let trigger: String
    let message: String?
    let kit: Kit
    let steps: [Step]
    let focusStepNumber: Int?
    let progressLog: [LogEntry]
    let busyMinutesByDay: [String: Int]
    let conversation: Conversation
    /// Idioma de la app («es» o «en»): la respuesta y la propuesta deben ir en este idioma.
    var language: String = AppLanguage.code
    /// Tipos de cambio que esta versión sabe aplicar además de los de siempre: el servidor solo propone
    /// «move_step» a quien lo declara, porque las versiones anteriores ignoran lo que no conocen.
    var capabilities: [String] = ["move_step"]
    /// Revisar el orden tras mover pasos a mano: el servidor lo compara con el plan original.
    var reviewOrder: Bool?
}

struct AssistResponse: Decodable {
    struct Change: Decodable {
        let type: String
        let stepNumber: Int?
        let newDate: String?
        let newTitles: [String]?
        let newMinutes: Int?
        /// move_step: posición final (1…n) en la lista completa, tal como se envió.
        let newPosition: Int?
        let reason: String?
        /// add_step y edit_step: qué queda hecho al terminar y cómo hacerlo. `reason` es por qué se propone, no el contenido del paso.
        let newOutcome: String?
        let newDescription: String?
        /// split_step: qué queda hecho y cómo hacer cada parte, en el orden de `newTitles`.
        let newOutcomes: [String]?
        let newDescriptions: [String]?
    }

    struct Proposal: Decodable {
        let scope: String?
        let summary: String
        let impact: String?
        let changes: [Change]
    }

    /// Lo que el asistente no puede hacer con cambios en este Kit: por ahora, proponer otro Kit
    /// («new_kit», con título y resultado para precargar el creador). Tipos desconocidos se ignoran.
    struct Suggestion: Decodable {
        let type: String
        let title: String?
        let goal: String?
        let reason: String?
    }

    let message: String
    let proposal: Proposal?
    let summary: String?
    let suggestion: Suggestion?
}

enum AssistTrigger: String {
    case message, blocked, overdue
}

// MARK: - Petición a partir del Kit

@MainActor
enum AssistRequestBuilder {
    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func day(_ date: Date?) -> String? { date.map { dayFormatter.string(from: $0) } }

    static func build(
        kit: GoalEntity,
        focus: StepEntity?,
        trigger: AssistTrigger,
        message: String?,
        conversation: KitConversation?,
        context: ModelContext,
        reviewOrder: Bool = false
    ) -> AssistRequest {
        let steps = kit.orderedActiveSteps
        let kitID = kit.id
        let entries = ((try? context.fetch(FetchDescriptor<ProgressEntryEntity>(
            predicate: #Predicate { $0.kitID == kitID },
            sortBy: [SortDescriptor(\.notedAt, order: .reverse)]
        ))) ?? []).filter { $0.deletedAt == nil }

        let number: (UUID?) -> Int? = { id in
            guard let id, let step = steps.first(where: { $0.id == id }) else { return nil }
            return kit.position(of: step)
        }

        let stepPayload = steps.map { step in
            AssistRequest.Step(
                number: kit.position(of: step),
                title: step.stepTitle,
                descriptionShort: step.descriptionShort,
                estimateMinutes: step.estimateMinutes,
                suggestedDeadline: day(step.suggestedDeadline),
                completed: step.isCompleted,
                blockedReason: step.blockedReason,
                repeatEvery: step.repeatEvery,
                repeatTimes: step.repeatTimes,
                sessionsDone: step.repetition == nil ? nil
                    : entries.filter { $0.stepID == step.id && $0.kind == .session }.count,
                planPosition: step.planPosition
            )
        }

        // Tiempo por sesión del Kit: el paso habitual (sin contar citas largas).
        let minutes = steps.map(\.estimateMinutes).sorted()
        let typical = minutes.isEmpty ? 30 : minutes[minutes.count / 2]

        let chat = conversation?.viewModel.messages.filter { !$0.isError }.suffix(6).map {
            AssistRequest.Message(role: $0.sender == .user ? "user" : "assistant", text: $0.text)
        } ?? []

        return AssistRequest(
            today: dayFormatter.string(from: .now),
            timezone: TimeZone.current.identifier,
            trigger: trigger.rawValue,
            message: message,
            kit: .init(title: kit.title, kpi: kit.kpi, dueDate: day(kit.dueDate),
                       dailyAvailableTime: max(10, typical), maxStepsPerDay: 3),
            steps: stepPayload,
            focusStepNumber: focus.map { kit.position(of: $0) },
            progressLog: entries.prefix(10).map {
                .init(stepNumber: number($0.stepID), kind: $0.kind.rawValue, note: $0.note, notedAt: $0.notedAt)
            },
            busyMinutesByDay: busyMinutes(excluding: kit, context: context),
            conversation: .init(summary: summary(conversation?.serverSummary,
                                                 discarded: conversation?.proposals.filter { $0.state == .discarded }.map(\.title) ?? []),
                                messages: Array(chat)),
            reviewOrder: reviewOrder ? true : nil
        )
    }

    /// El resumen viene del servidor, que no sabe qué propuestas descartó la persona: se lo decimos
    /// para que no las vuelva a ofrecer. Va en español, como el resto de instrucciones del asistente.
    static func summary(_ base: String?, discarded: [String]) -> String? {
        guard !discarded.isEmpty else { return base }
        let note = "La persona ya ha descartado estas propuestas; no las vuelvas a ofrecer: "
            + discarded.suffix(5).map { "«\($0)»" }.joined(separator: ", ") + "."
        guard let base, !base.isEmpty else { return note }
        return base + " " + note
    }

    /// Minutos ya ocupados cada día (otros Kits y sesiones, también las libres), de hoy a +60 días.
    static func busyMinutes(excluding kit: GoalEntity, context: ModelContext) -> [String: Int] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        guard let end = calendar.date(byAdding: .day, value: 61, to: start) else { return [:] }
        var result: [String: Int] = [:]
        func add(_ date: Date, _ minutes: Int) {
            guard date >= start, date < end, let key = day(date) else { return }
            result[key, default: 0] += minutes
        }
        let owner = kit.ownerID
        let kitID = kit.id
        let others = (try? context.fetch(FetchDescriptor<GoalEntity>(
            predicate: #Predicate { $0.ownerID == owner && !$0.isDeleted && $0.id != kitID }
        ))) ?? []
        for other in others {
            for step in other.orderedActiveSteps where !step.isCompleted {
                for date in step.sessionDates { add(date, step.estimateMinutes) }
            }
        }
        let sessions = (try? context.fetch(FetchDescriptor<WorkSessionEntity>(
            predicate: #Predicate { $0.ownerID == owner && $0.deletedAt == nil }
        ))) ?? []
        for session in sessions where session.kitID != kitID {
            add(session.startsAt, session.durationMinutes)
        }
        return result
    }
}

// MARK: - Cliente

enum KitAssistClient {
    enum Failure: Error { case unavailable, quotaExceeded, server(Int) }

    static func send(_ request: AssistRequest, apiClient: any APIClientProtocol, token: String) async throws -> AssistResponse {
        var urlRequest = apiClient.authenticatedRequest(path: "/ai/assist", method: "POST", token: token)
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        urlRequest.httpBody = try encoder.encode(request)
        urlRequest.timeoutInterval = 60
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else { throw Failure.unavailable }
        guard (200...299).contains(http.statusCode) else {
            // 429 es el cupo mensual de IA o, si no lo menciona, el límite de peticiones por minuto:
            // solo lo primero se arregla con Pro. 404: servidor sin asistente.
            if http.statusCode == 429 {
                let reason = String(decoding: data, as: UTF8.self).lowercased()
                throw reason.contains("quota") ? Failure.quotaExceeded : Failure.unavailable
            }
            throw http.statusCode == 404 ? Failure.unavailable : Failure.server(http.statusCode)
        }
        return try JSONDecoder().decode(AssistResponse.self, from: data)
    }
}

// MARK: - Propuesta del servidor → propuesta aplicable

@MainActor
enum RemoteProposalBuilder {
    private static let calendar = Calendar.current

    private static func label(_ kit: GoalEntity, _ step: StepEntity) -> String {
        String(localized: "Paso \(kit.position(of: step)) · \(step.stepTitle)")
    }

    static func build(_ remote: AssistResponse.Proposal, kit: GoalEntity, maxStepsPerDay: Int = 3) -> PlanProposal? {
        let steps = kit.orderedActiveSteps
        func step(_ number: Int?) -> StepEntity? {
            guard let number, number >= 1, number <= steps.count else { return nil }
            return steps[number - 1]
        }
        func date(_ text: String?) -> Date? {
            text.flatMap { AssistRequestBuilder.dayFormatter.date(from: $0) }
                .map { calendar.date(bySettingHour: 12, minute: 0, second: 0, of: $0) ?? $0 }
        }

        var changes: [ProposedStepChange] = []
        var actions: [PlanProposal.Action] = []
        // Fechas tras aplicar los cambios, para calcular el efecto dominó.
        var newDates: [UUID: Date] = [:]
        // Pasos añadidos: su fecha se decide al final, cuando se sabe dónde queda cada uno.
        var additions: [PendingAddition] = []
        var removedIDs: Set<UUID> = []
        // Posición final de cada paso que el asistente cambia de sitio.
        var moves: [Int: StepEntity] = [:]

        for change in remote.changes {
            switch change.type {
            case "move_step_date":
                guard let target = step(change.stepNumber), let to = date(change.newDate) else { continue }
                newDates[target.id] = to
            case "change_kit_due_date":
                guard let to = date(change.newDate), let last = steps.last(where: { !$0.isCompleted }) else { continue }
                actions.append(.setKitDueDate(to))
                if (newDates[last.id] ?? last.suggestedDeadline).map({ $0 < to }) ?? true {
                    newDates[last.id] = to
                }
                // Si la fecha se adelanta, nada puede quedar después.
                for s in steps where !s.isCompleted {
                    if let current = newDates[s.id] ?? s.suggestedDeadline, current > to { newDates[s.id] = to }
                }
            case "edit_step":
                guard let target = step(change.stepNumber) else { continue }
                // Solo lo que cambia: el título si es otro y los minutos de antes → después.
                let title = change.newTitles?.first.flatMap { $0 == target.stepTitle ? nil : $0 }
                let minutes = change.newMinutes.flatMap { $0 == target.estimateMinutes ? nil : $0 }
                let detail = [title.map { "«\($0)»" },
                              minutes.map { String(localized: "\(target.estimateMinutes) → \($0) min") },
                              title == nil && minutes == nil && change.newDescription != nil
                                ? String(localized: "Nueva descripción") : nil]
                    .compactMap { $0 }.joined(separator: " · ")
                changes.append(ProposedStepChange(stepID: target.id, stepLabel: label(kit, target), from: nil, to: nil,
                                                  detail: detail,
                                                  symbol: "pencil"))
                actions.append(.edit(stepID: target.id, title: title, minutes: minutes,
                                     outcome: change.newOutcome, description: change.newDescription))
            case "split_step":
                guard let target = step(change.stepNumber), let titles = change.newTitles, titles.count > 1 else { continue }
                // Las partes se quedan el día del paso: se dice el día una vez, no uno por parte.
                let parts = titles.map { String(localized: "«\($0)»") }.joined(separator: ", ")
                let detail = target.suggestedDeadline.map {
                    String(localized: "Se divide en \(titles.count) partes el \($0.formatted(.dateTime.day().month(.abbreviated))): \(parts)")
                } ?? String(localized: "Se divide en \(titles.count) partes: \(parts)")
                changes.append(ProposedStepChange(stepID: target.id, stepLabel: label(kit, target), from: nil, to: nil,
                                                  detail: detail, symbol: "square.split.2x1"))
                actions.append(.split(stepID: target.id, titles: titles, minutes: change.newMinutes,
                                      outcomes: change.newOutcomes, descriptions: change.newDescriptions))
            case "add_step":
                guard let title = change.newTitles?.first else { continue }
                // En un plan vacío, cada uno detrás del anterior: «al principio» los dejaría al revés.
                additions.append(PendingAddition(change: change, title: title, changeIndex: changes.count,
                                                 actionIndex: actions.count,
                                                 date: date(change.newDate) ?? (steps.isEmpty ? calendar.date(bySettingHour: 12, minute: 0, second: 0, of: .now) : nil),
                                                 // stepNumber = paso tras el que se inserta; 0 = al principio.
                                                 afterStepID: step(change.stepNumber)?.id, atStart: change.stepNumber == 0 && !steps.isEmpty))
                changes.append(additionChange(title: title, minutes: change.newMinutes, date: date(change.newDate)))
                actions.append(additionAction(additions[additions.count - 1], date: date(change.newDate)))
            case "move_step":
                // Los terminados se quedan en su sitio: ni se mueven ni se ocupa su hueco.
                guard let target = step(change.stepNumber), !target.isCompleted,
                      let position = change.newPosition, let destination = step(position), !destination.isCompleted,
                      moves[position] == nil else { continue }
                moves[position] = target
            case "remove_step":
                guard let target = step(change.stepNumber) else { continue }
                changes.append(ProposedStepChange(stepID: target.id, stepLabel: label(kit, target), from: nil, to: nil,
                                                  detail: String(localized: "Se quita del plan"), symbol: "minus.circle"))
                actions.append(.remove(stepID: target.id))
                removedIDs.insert(target.id)
            case "change_kit_kpi":
                guard let kpi = change.newTitles?.first, !kpi.isEmpty else { continue }
                changes.append(ProposedStepChange(stepID: nil, stepLabel: String(localized: "Meta del Kit"), from: nil, to: nil,
                                                  detail: String(localized: "«\(kit.kpi)» → «\(kpi)»"), symbol: "target"))
                actions.append(.changeKPI(kpi))
            case "mark_step_blocked":
                guard let target = step(change.stepNumber) else { continue }
                changes.append(ProposedStepChange(stepID: target.id, stepLabel: label(kit, target), from: nil, to: nil,
                                                  detail: String(localized: "Queda en pausa: \(change.reason ?? String(localized: "pendiente de resolver"))"),
                                                  symbol: Symbols.blocked))
                actions.append(.block(stepID: target.id, reason: change.reason ?? String(localized: "Pendiente de resolver")))
            default:
                continue
            }
        }

        var impact = remote.impact ?? String(localized: "El resto del plan no cambia.")
        if !moves.isEmpty {
            addMoves(moves, steps: steps, kit: kit, changes: &changes, actions: &actions)
        }
        let requestedMoves = !newDates.isEmpty
        if !additions.isEmpty {
            let resolved = resolveAdditions(additions, steps: steps.filter { !removedIDs.contains($0.id) },
                                            moves: newDates, maxStepsPerDay: maxStepsPerDay)
            for addition in additions {
                let final = resolved[addition.id]
                changes[addition.changeIndex] = additionChange(title: addition.title, minutes: addition.change.newMinutes, date: final)
                actions[addition.actionIndex] = additionAction(addition, date: final)
            }
            newDates = resolved
            // Lo que explica el modelo no contaba con estos ajustes.
            if !requestedMoves, steps.contains(where: { step in
                guard let to = resolved[step.id], let from = step.suggestedDeadline else { return false }
                return !calendar.isDate(from, inSameDayAs: to)
            }) {
                impact = String(localized: "Otros pasos se mueven para mantener el orden.")
            }
            if let target = kit.targetDate, PlanReschedule.passes(target: target, moves: resolved, calendar: calendar) {
                impact = String(localized: "Algún paso quedaría después de la fecha final del Kit, el \(target.formatted(.dateTime.day().month(.wide))).")
            }
        } else if !newDates.isEmpty {
            // Efecto dominó: el orden del plan se mantiene y ningún día pasa del máximo de pasos.
            newDates = PlanReschedule.dates(for: steps, overrides: newDates, maxStepsPerDay: maxStepsPerDay,
                                            calendar: calendar)
        }
        if !newDates.isEmpty {
            for s in steps {
                guard let to = newDates[s.id], let from = s.suggestedDeadline,
                      !calendar.isDate(from, inSameDayAs: to) else { continue }
                changes.append(ProposedStepChange(stepID: s.id, stepLabel: label(kit, s), from: from, to: to))
                actions.append(.setDate(stepID: s.id, date: to))
            }
        }

        guard !actions.isEmpty else { return nil }
        return PlanProposal(title: remote.summary, changes: changes, impact: impact, actions: actions)
    }

    /// Cada paso movido ocupa su hueco y los demás pendientes rellenan el resto en su orden. Las fechas
    /// las recalcula la app con la misma regla que «Editar pasos».
    private static func addMoves(
        _ moves: [Int: StepEntity],
        steps: [StepEntity],
        kit: GoalEntity,
        changes: inout [ProposedStepChange],
        actions: inout [PlanProposal.Action]
    ) {
        let movedIDs = Set(moves.values.map(\.id))
        var rest = steps.filter { !$0.isCompleted && !movedIDs.contains($0.id) }[...]
        var pendingOrder: [UUID] = []
        for (index, step) in steps.enumerated() where !step.isCompleted {
            if let moved = moves[index + 1] {
                pendingOrder.append(moved.id)
            } else if let next = rest.popFirst() {
                pendingOrder.append(next.id)
            }
        }
        var draft = StepListDraft(kit: kit)
        draft.setPendingOrder(pendingOrder)
        let order = draft.finalOrder
        for position in moves.keys.sorted() {
            guard let moved = moves[position] else { continue }
            changes.append(ProposedStepChange(stepID: moved.id, stepLabel: label(kit, moved), from: nil, to: nil,
                                              detail: String(localized: "Pasa a ser el paso \(position)"),
                                              symbol: "arrow.up.arrow.down"))
            actions.append(.reorder(order: order, movedStepID: moved.id))
        }
        let planned = draft.plannedDates(calendar: calendar)
        for step in steps {
            guard let to = planned[step.id], let from = step.suggestedDeadline,
                  !calendar.isDate(from, inSameDayAs: to) else { continue }
            changes.append(ProposedStepChange(stepID: step.id, stepLabel: label(kit, step), from: from, to: to))
            actions.append(.setDate(stepID: step.id, date: to))
        }
    }

    private struct PendingAddition {
        let id = UUID()
        let change: AssistResponse.Change
        let title: String
        let changeIndex: Int
        let actionIndex: Int
        let date: Date?
        let afterStepID: UUID?
        let atStart: Bool
    }

    private static func additionChange(title: String, minutes: Int?, date: Date?) -> ProposedStepChange {
        ProposedStepChange(stepID: nil, stepLabel: String(localized: "Paso nuevo · \(title)"), from: nil, to: date,
                           detail: minutes.map { String(localized: "\($0) min") }, symbol: "plus.circle")
    }

    private static func additionAction(_ addition: PendingAddition, date: Date?) -> PlanProposal.Action {
        .add(afterStepID: addition.afterStepID, atStart: addition.atStart, title: addition.title,
             minutes: addition.change.newMinutes ?? 20, date: date,
             outcome: addition.change.newOutcome, description: addition.change.newDescription)
    }

    /// El paso nuevo nunca queda antes que el anterior, y los siguientes solo se mueven si hace falta.
    /// Los que van antes del primer paso añadido no se tocan, salvo que la propuesta también mueva fechas.
    private static func resolveAdditions(
        _ additions: [PendingAddition],
        steps: [StepEntity],
        moves: [UUID: Date],
        maxStepsPerDay: Int
    ) -> [UUID: Date] {
        var slots = steps.map {
            PlanReschedule.Slot(id: $0.id, date: moves[$0.id] ?? $0.suggestedDeadline, isCompleted: $0.isCompleted)
        }
        // Mismo orden en que se aplican: cada paso nuevo entra justo detrás de su referencia.
        for addition in additions {
            let index: Int
            if addition.atStart {
                index = 0
            } else if let anchor = addition.afterStepID, let position = slots.firstIndex(where: { $0.id == anchor }) {
                index = position + 1
            } else {
                index = slots.count
            }
            slots.insert(PlanReschedule.Slot(id: addition.id, date: addition.date, isCompleted: false), at: index)
        }
        let addedIDs = Set(additions.map(\.id))
        for index in slots.indices where addedIDs.contains(slots[index].id) && slots[index].date == nil {
            let pending = slots.filter { !$0.isCompleted && $0.date != nil }
            let before = slots[..<index].last { !$0.isCompleted && $0.date != nil }
            slots[index].date = before?.date ?? pending.first?.date
        }
        if moves.isEmpty, let first = slots.firstIndex(where: { addedIDs.contains($0.id) }) {
            for index in slots[..<first].indices { slots[index].isFixed = true }
        }
        return PlanReschedule.resolve(slots, maxStepsPerDay: maxStepsPerDay, calendar: calendar)
    }
}

// MARK: - Uso desde la app

@MainActor
enum KitAssistant {
    /// Pregunta al asistente del servidor y deja la respuesta (y la propuesta, si hay) en la conversación.
    /// Devuelve false si el servidor no tiene asistente, no hay sesión o no hay permiso de IA externa:
    /// la app usa entonces el modelo local y no sale nada del dispositivo.
    @discardableResult
    static func ask(
        _ trigger: AssistTrigger,
        message: String? = nil,
        kit: GoalEntity,
        step: StepEntity?,
        conversation: KitConversation,
        context: ModelContext,
        apiClient: any APIClientProtocol,
        token: String?,
        reviewOrder: Bool = false
    ) async -> Bool {
        guard let token, AIConsentManager().hasConsent else { return false }
        let request = AssistRequestBuilder.build(kit: kit, focus: step, trigger: trigger, message: message,
                                                 conversation: conversation, context: context, reviewOrder: reviewOrder)
        let vm = conversation.viewModel
        let visible = trigger == .message
        if visible { vm.isTyping = true; vm.isResponding = true }
        defer { if visible { vm.isTyping = false; vm.isResponding = false } }
        do {
            let response = try await KitAssistClient.send(request, apiClient: apiClient, token: token)
            // Permiso retirado mientras esperábamos: se descarta la respuesta.
            guard AIConsentManager().hasConsent else { return false }
            conversation.serverSummary = response.summary ?? conversation.serverSummary
            conversation.quotaReached = false
            // Cada respuesta decide si sigue en pie la sugerencia de crear otro Kit.
            conversation.newKitSuggestion = response.suggestion.flatMap { $0.type == "new_kit" ? $0 : nil }
            var proposal = response.proposal.flatMap { RemoteProposalBuilder.build($0, kit: kit) }
            var text = response.message.trimmingCharacters(in: .whitespacesAndNewlines)
            if let repeated = proposal, conversation.wasDiscarded(repeated) {
                // La respuesta puede seguir siendo útil; solo se quita lo ya rechazado, y se dice.
                proposal = nil
                let note = String(localized: "Esa propuesta ya la descartaste, así que no te la vuelvo a ofrecer.")
                text = text.isEmpty ? note : text + "\n\n" + note
            }
            if !text.isEmpty || proposal != nil {
                vm.messages.append(ChatMessage(sender: .assistant,
                                               text: text.isEmpty ? String(localized: "Te propongo un ajuste del plan.") : text,
                                               fromServer: true))
            }
            if let proposal { conversation.add(proposal) }
            return true
        } catch KitAssistClient.Failure.quotaExceeded {
            // Las reacciones automáticas no dicen nada: no lo ha pedido la persona.
            if visible { conversation.quotaReached = true }
            return true
        } catch KitAssistClient.Failure.unavailable {
            return false
        } catch {
            if visible {
                vm.messages.append(ChatMessage(sender: .assistant, text: String(localized: "No he podido responder ahora. Inténtalo de nuevo en un momento."),
                                               isError: true))
            }
            return true
        }
    }

    /// Reacción automática, solo al bloquear un paso o si se vence: ahí ayuda sin que se lo pidas.
    static func react(
        _ trigger: AssistTrigger,
        message: String? = nil,
        kit: GoalEntity,
        step: StepEntity?,
        context: ModelContext,
        apiClient: any APIClientProtocol,
        token: String?
    ) {
        let conversation = step.map { KitAssistantStore.shared.conversation(kit: kit, step: $0) }
            ?? KitAssistantStore.shared.conversations(for: kit.id).first { $0.stepID == nil }
            ?? KitAssistantStore.shared.newConversation(kit: kit, title: String(localized: "Ajustes del plan"))
        // Lo que ha escrito la persona va al hilo y al asistente: si no, contesta a lo último que se habló.
        if let message, AIConsentManager().hasConsent {
            conversation.viewModel.messages.append(ChatMessage(sender: .user, text: message))
        }
        Task { await ask(trigger, message: message, kit: kit, step: step, conversation: conversation, context: context,
                         apiClient: apiClient, token: token) }
    }
}
