//
//  StepListEditor.swift
//  StepKit
//
//  Regla única para cambiar la lista de pasos de un Kit (asistente, edición a mano y creación a mano):
//  tras cada cambio, los pasos activos quedan numerados de 0 a n, sin huecos ni repetidos.
//

import Foundation
import SwiftData

enum StepListEditor {
    /// Añade un paso al Kit. Sin `anchor`: al principio con `atStart`, si no, al final.
    @discardableResult
    static func insert(
        title: String,
        minutes: Int,
        date: Date?,
        after anchor: StepEntity? = nil,
        atStart: Bool = false,
        short: String = "",
        long: String = "",
        into kit: GoalEntity,
        context: ModelContext,
        at now: Date = Date()
    ) -> StepEntity {
        var steps = kit.orderedActiveSteps
        let index: Int
        if atStart {
            index = 0
        } else if let anchor, let position = steps.firstIndex(where: { $0.id == anchor.id }) {
            index = position + 1
        } else {
            index = steps.count
        }
        let new = StepEntity(ownerID: kit.ownerID, stepTitle: title, descriptionShort: short, descriptionLong: long,
                             estimateMinutes: minutes, suggestedDeadline: date ?? anchor?.suggestedDeadline,
                             effortLevel: anchor?.effortLevel ?? "medium",
                             order: index,
                             createdAt: now, updatedAt: now)
        context.insert(new)
        // Solo el append: `steps` tiene inversa en `goal`, así que asignar también `new.goal = kit`
        // dejaba el mismo paso dos veces en la lista (el Kit pasaba de 6 a 7 con un paso repetido,
        // el asistente veía un duplicado que no podía quitar y «paso 2» apuntaba a otro paso).
        kit.steps.append(new)
        steps.insert(new, at: index)
        assignOrder(to: steps, at: now)
        return new
    }

    /// Borrado lógico del paso; los demás cierran el hueco.
    static func remove(_ step: StepEntity, from kit: GoalEntity, at now: Date = Date()) {
        step.deletedAt = now
        step.markModified(at: now)
        renumber(kit, at: now)
    }

    /// Lleva el paso a `index` dentro de los pasos activos (se recorta al rango válido).
    static func move(_ step: StepEntity, to index: Int, in kit: GoalEntity, at now: Date = Date()) {
        var steps = kit.orderedActiveSteps
        guard let current = steps.firstIndex(where: { $0.id == step.id }) else { return }
        steps.remove(at: current)
        steps.insert(step, at: min(max(index, 0), steps.count))
        assignOrder(to: steps, at: now)
    }

    /// Numera los pasos activos de 0 a n. Solo marca como modificados los que cambian, para sincronizar lo justo.
    static func renumber(_ kit: GoalEntity, at now: Date = Date()) {
        assignOrder(to: kit.orderedActiveSteps, at: now)
    }

    /// Reparte los pasos dados, en su orden, del primer día al último. La fecha final manda sobre
    /// `PlanReschedule.maxStepsPerDay`: con muchos pasos y pocos días, un día puede superar ese máximo.
    static func distributeDates(
        of steps: [StepEntity],
        from start: Date,
        to end: Date,
        calendar: Calendar = .current,
        at now: Date = Date()
    ) {
        let first = calendar.startOfDay(for: start)
        let last = calendar.startOfDay(for: end)
        let days = max(calendar.dateComponents([.day], from: first, to: last).day ?? 0, 0)
        for (index, step) in steps.enumerated() {
            let offset = steps.count > 1 ? days * index / (steps.count - 1) : 0
            guard let date = calendar.date(byAdding: .day, value: offset, to: first) else { continue }
            if let current = step.suggestedDeadline, calendar.isDate(current, inSameDayAs: date) { continue }
            step.suggestedDeadline = date
            step.markModified(at: now)
        }
    }

    private static func assignOrder(to steps: [StepEntity], at now: Date) {
        for (index, step) in steps.enumerated() where step.order != index {
            step.order = index
            step.markModified(at: now)
        }
    }
}
