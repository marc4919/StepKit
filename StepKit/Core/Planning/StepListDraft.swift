//
//  StepListDraft.swift
//  StepKit
//
//  Borrador de la lista de pasos de un Kit: nada cambia en el Kit hasta `apply`, así «Cancelar» lo
//  deja todo como estaba y las fechas solo se ajustan al guardar.
//

import Foundation
import SwiftData
import SwiftUI

struct StepDraft: Identifiable, Equatable {
    let id: UUID
    var title: String
    var short: String
    var long: String
    var minutes: Int
    var date: Date?
    let isCompleted: Bool
    let isNew: Bool

    init(step: StepEntity) {
        id = step.id
        title = step.stepTitle
        short = step.descriptionShort
        long = step.descriptionLong
        minutes = step.estimateMinutes
        date = step.suggestedDeadline
        isCompleted = step.isCompleted
        isNew = false
    }

    init(id: UUID = UUID(), title: String = "", short: String = "", long: String = "", minutes: Int = 20, date: Date?) {
        self.id = id
        self.title = title
        self.short = short
        self.long = long
        self.minutes = minutes
        self.date = date
        isCompleted = false
        isNew = true
    }

    /// Sin espacios sobrantes, igual que al editar un paso.
    var normalized: StepDraft {
        var copy = self
        copy.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.short = short.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.long = long.trimmingCharacters(in: .whitespacesAndNewlines)
        return copy
    }

    var isValid: Bool { !normalized.title.isEmpty }
}

struct StepListDraft: Equatable {
    /// Un cambio de día que hará falta al guardar, para enseñarlo antes.
    struct DateChange: Equatable {
        let title: String
        let from: Date?
        let to: Date
    }

    private(set) var pending: [StepDraft]
    private(set) var completed: [StepDraft]
    private(set) var removedIDs: Set<UUID> = []
    private let saved: [UUID: StepDraft]
    private let savedOrder: [UUID]

    init(kit: GoalEntity) {
        let steps = kit.orderedActiveSteps.map(StepDraft.init(step:))
        pending = steps.filter { !$0.isCompleted }
        completed = steps.filter(\.isCompleted)
        saved = Dictionary(uniqueKeysWithValues: steps.map { ($0.id, $0) })
        savedOrder = steps.map(\.id)
    }

    var totalCount: Int { pending.count + completed.count }

    var lastPendingDate: Date? { pending.last { $0.date != nil }?.date }

    var hasChanges: Bool {
        !removedIDs.isEmpty || pending.map(\.id) != savedOrder.filter { saved[$0]?.isCompleted == false }
            || (pending + completed).contains { saved[$0.id] != $0 }
    }

    /// Se quitó un paso guardado o cambió el orden de los que ya había. Añadir o retocar textos no cuenta.
    var changesPlanStructure: Bool {
        guard removedIDs.isEmpty else { return true }
        let kept = pending.filter { !$0.isNew }.map(\.id)
        return kept != savedOrder.filter { kept.contains($0) }
    }

    /// Qué pasos cambiaron de sitio o se quitaron, para contárselo al asistente. Solo los movidos de
    /// verdad, no los que se desplazan por ellos, y limitado: el mensaje al servidor tiene un tamaño máximo.
    var structureSummary: String {
        let maxLines = 8
        let order = finalOrder
        let stayed = stayedIDs
        var lines: [String] = pending.compactMap { step in
            guard !step.isNew, !stayed.contains(step.id),
                  let from = savedOrder.firstIndex(of: step.id), let to = order.firstIndex(of: step.id) else { return nil }
            return String(localized: "«\(step.title)» pasó del paso \(from + 1) al \(to + 1).")
        }
        lines += savedOrder.filter(removedIDs.contains).compactMap { id in
            saved[id].map { String(localized: "Quité «\($0.title)».") }
        }
        return lines.prefix(maxLines).joined(separator: " ")
    }

    mutating func movePending(fromOffsets source: IndexSet, toOffset destination: Int) {
        pending.move(fromOffsets: source, toOffset: destination)
    }

    mutating func add(_ step: StepDraft) {
        pending.append(step.normalized)
    }

    mutating func update(_ step: StepDraft) {
        if let index = pending.firstIndex(where: { $0.id == step.id }) {
            pending[index] = step.normalized
        } else if let index = completed.firstIndex(where: { $0.id == step.id }) {
            completed[index] = step.normalized
        }
    }

    mutating func remove(_ id: UUID) {
        guard let index = pending.firstIndex(where: { $0.id == id }) else { return }
        if !pending[index].isNew { removedIDs.insert(id) }
        pending.remove(at: index)
    }

    // MARK: - Fechas

    /// Pasos que cambian de sitio (los menos posibles), nuevos o con otra fecha. Los demás conservan la suya
    /// salvo que haga falta moverlos.
    private func movedIDs(calendar: Calendar) -> Set<UUID> {
        chosenDateIDs(calendar: calendar).union(pending.map(\.id).filter { saved[$0] == nil || !stayedIDs.contains($0) })
    }

    /// Pasos con una fecha elegida a mano en el formulario: nuevos o con otro día.
    private func chosenDateIDs(calendar: Calendar) -> Set<UUID> {
        Set(pending.filter { step in
            guard let date = step.date else { return false }
            guard let original = saved[step.id] else { return true }
            return original.date.map { !calendar.isDate($0, inSameDayAs: date) } ?? true
        }.map(\.id))
    }

    /// Pasos guardados que conservan su orden relativo: los demás son los que se han movido.
    private var stayedIDs: Set<UUID> {
        let existing = pending.filter { saved[$0.id] != nil }
        let originalIndex = Dictionary(uniqueKeysWithValues: savedOrder.enumerated().map { ($1, $0) })
        // Subsecuencia creciente más larga: los que forman parte de ella no se han movido.
        var best = Array(repeating: 1, count: existing.count)
        var previous = Array(repeating: -1, count: existing.count)
        for i in existing.indices {
            for j in existing.indices where j < i {
                if originalIndex[existing[j].id, default: 0] < originalIndex[existing[i].id, default: 0], best[j] + 1 > best[i] {
                    best[i] = best[j] + 1
                    previous[i] = j
                }
            }
        }
        var stayed = Set<UUID>()
        var cursor = best.indices.max { best[$0] < best[$1] } ?? -1
        while cursor >= 0 {
            stayed.insert(existing[cursor].id)
            cursor = previous[cursor]
        }
        return stayed
    }

    /// Fecha final de los pasos pendientes. El paso movido toma la del anterior (o la del siguiente, si
    /// queda el primero) cuando la suya ya no cabe; los siguientes solo se mueven si hace falta.
    /// La fecha elegida a mano se respeta: solo se corrige si quedaría antes que el paso anterior.
    func plannedDates(calendar: Calendar = .current) -> [UUID: Date] {
        let moved = movedIDs(calendar: calendar)
        guard let first = pending.firstIndex(where: { moved.contains($0.id) }) else { return [:] }
        let chosen = chosenDateIDs(calendar: calendar)
        func day(_ date: Date) -> Date { calendar.startOfDay(for: date) }

        var dates = pending.map(\.date)
        for index in pending.indices where moved.contains(pending[index].id) {
            let before = dates[..<index].last { $0 != nil } ?? nil
            let after = pending.indices.filter { $0 > index && !moved.contains(pending[$0].id) }
                .lazy.compactMap { dates[$0] }.first
            let fits = dates[index].map { date in
                (before.map { day($0) <= day(date) } ?? true)
                    && (chosen.contains(pending[index].id) || after.map { day(date) <= day($0) } ?? true)
            } ?? false
            if !fits { dates[index] = before ?? after ?? dates[index] }
        }
        let slots = pending.indices.map { index in
            PlanReschedule.Slot(id: pending[index].id, date: dates[index], isCompleted: false, isFixed: index < first,
                                isChosen: chosen.contains(pending[index].id))
        }
        return PlanReschedule.resolve(slots, calendar: calendar)
    }

    /// Días que cambiarán al guardar, respecto a lo que hay en el borrador.
    func dateChanges(calendar: Calendar = .current) -> [DateChange] {
        let planned = plannedDates(calendar: calendar)
        return pending.compactMap { step in
            guard let to = planned[step.id] else { return nil }
            if let from = step.date, calendar.isDate(from, inSameDayAs: to) { return nil }
            return DateChange(title: step.title, from: step.date, to: to)
        }
    }

    /// Si con el borrador algún paso queda después de la fecha indicada.
    func passes(target: Date, calendar: Calendar = .current) -> Bool {
        let planned = plannedDates(calendar: calendar)
        let dates = pending.compactMap { planned[$0.id] ?? $0.date }
        return dates.max().map { calendar.startOfDay(for: $0) > calendar.startOfDay(for: target) } ?? false
    }

    // MARK: - Guardar

    /// Los pasos terminados no cambian de sitio: los pendientes ocupan los huecos que ya tenían.
    private var finalOrder: [UUID] {
        var queue = pending.map(\.id)[...]
        var result: [UUID] = []
        for id in savedOrder where !removedIDs.contains(id) {
            if saved[id]?.isCompleted == true {
                result.append(id)
            } else if let next = queue.popFirst() {
                result.append(next)
            }
        }
        return result + queue
    }

    /// Aplica el borrador al Kit y devuelve las sesiones que pasan al Kit (ver `StepListEditor.remove`).
    @discardableResult
    func apply(to kit: GoalEntity, context: ModelContext, calendar: Calendar = .current, at now: Date = Date()) -> [WorkSessionEntity] {
        let planned = plannedDates(calendar: calendar)
        var detached: [WorkSessionEntity] = []
        func step(_ id: UUID) -> StepEntity? { kit.orderedActiveSteps.first { $0.id == id } }

        for id in removedIDs {
            if let target = step(id) { detached += StepListEditor.remove(target, from: kit, context: context, at: now) }
        }
        for draft in pending + completed {
            if draft.isNew {
                StepListEditor.insert(id: draft.id, title: draft.title, minutes: draft.minutes, date: draft.date,
                                      short: draft.short, long: draft.long, into: kit, context: context, at: now)
            } else if let target = step(draft.id), saved[draft.id] != draft {
                target.stepTitle = draft.title
                target.descriptionShort = draft.short
                target.descriptionLong = draft.long
                target.estimateMinutes = draft.minutes
                target.markModified(at: now)
            }
        }
        StepListEditor.setOrder(finalOrder, of: kit, at: now)
        for draft in pending {
            guard let target = step(draft.id), let date = planned[draft.id] ?? draft.date else { continue }
            if let current = target.suggestedDeadline, calendar.isDate(current, inSameDayAs: date) { continue }
            target.suggestedDeadline = date
            target.markModified(at: now)
        }
        kit.markModified(at: now)
        return detached
    }
}
