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
}

struct AssistResponse: Decodable {
    struct Change: Decodable {
        let type: String
        let stepNumber: Int?
        let newDate: String?
        let newTitles: [String]?
        let newMinutes: Int?
        let reason: String?
        /// add_step: qué queda hecho al terminar y cómo hacerlo. `reason` es por qué se propone, no el contenido del paso.
        let newOutcome: String?
        let newDescription: String?
    }

    struct Proposal: Decodable {
        let scope: String?
        let summary: String
        let impact: String?
        let changes: [Change]
    }

    let message: String
    let proposal: Proposal?
    let summary: String?
}

enum AssistTrigger: String {
    case message, blocked, progress, overdue, edited
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
        context: ModelContext
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
                    : entries.filter { $0.stepID == step.id && $0.kind == .session }.count
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
            conversation: .init(summary: conversation?.serverSummary, messages: Array(chat))
        )
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
    enum Failure: Error { case unavailable, server(Int) }

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
            // 404: servidor sin asistente. 429: cupo de IA del plan gratuito agotado.
            // En ambos casos responde el modelo del dispositivo, que no tiene cupo.
            throw [404, 429].contains(http.statusCode) ? Failure.unavailable : Failure.server(http.statusCode)
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

        for change in remote.changes {
            switch change.type {
            case "move_step_date":
                guard let target = step(change.stepNumber), let to = date(change.newDate) else { continue }
                newDates[target.id] = to
            case "change_kit_due_date":
                guard let to = date(change.newDate), let last = steps.last(where: { !$0.isCompleted }) else { continue }
                if (newDates[last.id] ?? last.suggestedDeadline).map({ $0 < to }) ?? true {
                    newDates[last.id] = to
                }
                // Si la fecha se adelanta, nada puede quedar después.
                for s in steps where !s.isCompleted {
                    if let current = newDates[s.id] ?? s.suggestedDeadline, current > to { newDates[s.id] = to }
                }
            case "edit_step":
                guard let target = step(change.stepNumber) else { continue }
                let title = change.newTitles?.first
                changes.append(ProposedStepChange(stepID: target.id, stepLabel: label(kit, target), from: nil, to: nil,
                                                  detail: [title.map { "«\($0)»" },
                                                           change.newMinutes.map { String(localized: "\($0) min") }]
                                                    .compactMap { $0 }.joined(separator: " · "),
                                                  symbol: "pencil"))
                actions.append(.edit(stepID: target.id, title: title, minutes: change.newMinutes))
            case "split_step":
                guard let target = step(change.stepNumber), let titles = change.newTitles, titles.count > 1 else { continue }
                let days = target.suggestedDeadline.map { first in
                    titles.indices.compactMap { calendar.date(byAdding: .day, value: $0, to: first) }
                        .map { $0.formatted(.dateTime.day().month(.abbreviated)) }
                } ?? []
                let parts = zip(titles, days + Array(repeating: "", count: max(0, titles.count - days.count)))
                    .map { title, day in day.isEmpty ? String(localized: "«\(title)»") : String(localized: "«\(title)» (\(day))") }
                changes.append(ProposedStepChange(stepID: target.id, stepLabel: label(kit, target), from: nil, to: nil,
                                                  detail: String(localized: "Se divide en: ") + parts.joined(separator: ", "),
                                                  symbol: "square.split.2x1"))
                actions.append(.split(stepID: target.id, titles: titles, minutes: change.newMinutes))
            case "add_step":
                guard let title = change.newTitles?.first else { continue }
                changes.append(ProposedStepChange(stepID: nil, stepLabel: String(localized: "Paso nuevo · \(title)"), from: nil, to: date(change.newDate),
                                                  detail: change.newMinutes.map { String(localized: "\($0) min") }, symbol: "plus.circle"))
                // stepNumber = paso tras el que se inserta; 0 = al principio.
                actions.append(.add(afterStepID: step(change.stepNumber)?.id, atStart: change.stepNumber == 0,
                                    title: title, minutes: change.newMinutes ?? 20, date: date(change.newDate),
                                    outcome: change.newOutcome, description: change.newDescription))
            case "remove_step":
                guard let target = step(change.stepNumber) else { continue }
                changes.append(ProposedStepChange(stepID: target.id, stepLabel: label(kit, target), from: nil, to: nil,
                                                  detail: String(localized: "Se quita del plan"), symbol: "minus.circle"))
                actions.append(.remove(stepID: target.id))
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

        // Efecto dominó: el orden del plan se mantiene y ningún día pasa del máximo de pasos.
        if !newDates.isEmpty {
            newDates = PlanReschedule.dates(for: steps, overrides: newDates, maxStepsPerDay: maxStepsPerDay,
                                            calendar: calendar)
            for s in steps {
                guard let to = newDates[s.id], let from = s.suggestedDeadline,
                      !calendar.isDate(from, inSameDayAs: to) else { continue }
                changes.append(ProposedStepChange(stepID: s.id, stepLabel: label(kit, s), from: from, to: to))
                actions.append(.setDate(stepID: s.id, date: to))
            }
        }

        guard !actions.isEmpty else { return nil }
        return PlanProposal(title: remote.summary, changes: changes,
                            impact: remote.impact ?? String(localized: "El resto del plan no cambia."), actions: actions)
    }
}

// MARK: - Uso desde la app

@MainActor
enum KitAssistant {
    /// Pregunta al asistente del servidor y deja la respuesta (y la propuesta, si hay) en la conversación.
    /// Devuelve false si el servidor no tiene asistente o no hay sesión: la app usa entonces el modelo local.
    @discardableResult
    static func ask(
        _ trigger: AssistTrigger,
        message: String? = nil,
        kit: GoalEntity,
        step: StepEntity?,
        conversation: KitConversation,
        context: ModelContext,
        apiClient: any APIClientProtocol,
        token: String?
    ) async -> Bool {
        guard let token else { return false }
        let request = AssistRequestBuilder.build(kit: kit, focus: step, trigger: trigger, message: message,
                                                 conversation: conversation, context: context)
        let vm = conversation.viewModel
        let visible = trigger == .message
        if visible { vm.isTyping = true; vm.isResponding = true }
        defer { if visible { vm.isTyping = false; vm.isResponding = false } }
        do {
            let response = try await KitAssistClient.send(request, apiClient: apiClient, token: token)
            conversation.serverSummary = response.summary ?? conversation.serverSummary
            let proposal = response.proposal.flatMap { RemoteProposalBuilder.build($0, kit: kit) }
            let text = response.message.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty || proposal != nil {
                vm.messages.append(ChatMessage(sender: .assistant,
                                               text: text.isEmpty ? String(localized: "Te propongo un ajuste del plan.") : text,
                                               fromServer: true))
            }
            if let proposal { conversation.add(proposal) }
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

    /// Reacción automática (bloqueo, avance, paso vencido, edición): solo deja algo si aporta.
    static func react(
        _ trigger: AssistTrigger,
        kit: GoalEntity,
        step: StepEntity?,
        context: ModelContext,
        apiClient: any APIClientProtocol,
        token: String?
    ) {
        let conversation = step.map { KitAssistantStore.shared.conversation(kit: kit, step: $0) }
            ?? KitAssistantStore.shared.conversations(for: kit.id).first { $0.stepID == nil }
            ?? KitAssistantStore.shared.newConversation(kit: kit, title: String(localized: "Ajustes del plan"))
        Task { await ask(trigger, kit: kit, step: step, conversation: conversation, context: context,
                         apiClient: apiClient, token: token) }
    }
}
