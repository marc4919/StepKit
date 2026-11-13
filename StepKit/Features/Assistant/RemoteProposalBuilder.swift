//
//  RemoteProposalBuilder.swift
//  StepKit
//

import Foundation
import SwiftData

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
                // Las partes van aparte, como lista: en una frase seguida costaba leerlas.
                let detail = target.suggestedDeadline.map {
                    String(localized: "Se divide en \(titles.count) partes · \($0.formatted(.dateTime.day().month(.abbreviated)))")
                } ?? String(localized: "Se divide en \(titles.count) partes")
                changes.append(ProposedStepChange(stepID: target.id, stepLabel: label(kit, target), from: nil, to: nil,
                                                  detail: detail, symbol: "square.split.2x1", parts: titles,
                                                  logDetail: String(localized: "dividido en \(titles.count) partes")))
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
