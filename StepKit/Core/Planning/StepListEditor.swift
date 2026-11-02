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
    /// El servidor no acepta más pasos en un Kit al hablar con el asistente.
    static let maxSteps = 60

    /// Añade un paso al Kit. Sin `anchor`: al principio con `atStart`, si no, al final.
    @discardableResult
    static func insert(
        id: UUID = UUID(),
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
        let new = StepEntity(id: id, ownerID: kit.ownerID, stepTitle: title, descriptionShort: short, descriptionLong: long,
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

    /// Borrado lógico del paso; los demás cierran el hueco y sus sesiones pasan al Kit, para no perder
    /// tiempo reservado. Devuelve esas sesiones: su aviso nombraba el paso (ver `refreshReminders`).
    @discardableResult
    static func remove(
        _ step: StepEntity,
        from kit: GoalEntity,
        context: ModelContext,
        at now: Date = Date()
    ) -> [WorkSessionEntity] {
        step.deletedAt = now
        step.markModified(at: now)
        renumber(kit, at: now)
        let detached = sessions(of: step, in: kit, context: context)
        for session in detached {
            session.stepID = nil
            session.markModified(at: now)
        }
        return detached
    }

    /// Sesiones activas reservadas para el paso.
    static func sessions(of step: StepEntity, in kit: GoalEntity, context: ModelContext) -> [WorkSessionEntity] {
        let kitID = kit.id
        let descriptor = FetchDescriptor<WorkSessionEntity>(predicate: #Predicate { $0.kitID == kitID })
        return ((try? context.fetch(descriptor)) ?? []).filter { $0.stepID == step.id && $0.deletedAt == nil }
    }

    /// Lleva el paso a `index` dentro de los pasos activos (se recorta al rango válido).
    static func move(_ step: StepEntity, to index: Int, in kit: GoalEntity, at now: Date = Date()) {
        var steps = kit.orderedActiveSteps
        guard let current = steps.firstIndex(where: { $0.id == step.id }) else { return }
        steps.remove(at: current)
        steps.insert(step, at: min(max(index, 0), steps.count))
        assignOrder(to: steps, at: now)
    }

    /// Deja los pasos activos en el orden dado; los que no aparezcan quedan al final.
    static func setOrder(_ ids: [UUID], of kit: GoalEntity, at now: Date = Date()) {
        let steps = kit.orderedActiveSteps
        let positions = Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($1, $0) })
        let sorted = steps.enumerated().sorted {
            (positions[$0.element.id] ?? ids.count + $0.offset) < (positions[$1.element.id] ?? ids.count + $1.offset)
        }.map(\.element)
        assignOrder(to: sorted, at: now)
    }

    /// Rehace los avisos de las sesiones que han pasado al Kit: ya no deben nombrar el paso borrado.
    @MainActor
    static func refreshReminders(of sessions: [WorkSessionEntity], kit: GoalEntity) {
        let withReminder = sessions.filter(\.reminderEnabled)
        guard !withReminder.isEmpty else { return }
        let title = kit.title
        Task { @MainActor in
            for session in withReminder {
                await NotificationService.shared.scheduleReminder(for: session, kitTitle: title, stepTitle: nil)
            }
        }
    }

    /// Numera los pasos activos de 0 a n. Solo marca como modificados los que cambian, para sincronizar lo justo.
    static func renumber(_ kit: GoalEntity, at now: Date = Date()) {
        assignOrder(to: kit.orderedActiveSteps, at: now)
    }

    private static func assignOrder(to steps: [StepEntity], at now: Date) {
        for (index, step) in steps.enumerated() where step.order != index {
            step.order = index
            step.markModified(at: now)
        }
    }
}
