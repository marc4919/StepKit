//
//  PlanReschedule.swift
//  StepKit
//
//  Regla única para mover fechas del plan (asistente y «Editar paso»):
//  se mantiene el orden de los pasos y ningún día pasa del máximo de pasos.
//

import Foundation

enum PlanReschedule {
    static let maxStepsPerDay = 3

    /// Si alguna de las fechas nuevas queda después de la fecha final del Kit (se compara por días).
    static func passes(target: Date, moves: [UUID: Date], calendar: Calendar = .current) -> Bool {
        guard let latest = moves.values.max() else { return false }
        return calendar.startOfDay(for: latest) > calendar.startOfDay(for: target)
    }

    /// Fechas nuevas de los pasos pendientes tras aplicar `overrides` (id → fecha deseada).
    /// Devuelve solo los pasos cuyo día cambia, incluidos los de `overrides`.
    static func dates(
        for steps: [StepEntity],
        overrides: [UUID: Date],
        maxStepsPerDay: Int = maxStepsPerDay,
        calendar: Calendar = .current
    ) -> [UUID: Date] {
        let slots = steps.map {
            Slot(id: $0.id, date: overrides[$0.id] ?? $0.suggestedDeadline, isCompleted: $0.isCompleted)
        }
        let resolved = resolve(slots, maxStepsPerDay: maxStepsPerDay, calendar: calendar)
        return resolved.filter { id, date in
            guard let original = steps.first(where: { $0.id == id })?.suggestedDeadline else { return true }
            return !calendar.isDate(original, inSameDayAs: date)
        }
    }

    /// Un paso del plan, ya exista o sea uno nuevo que aún no se ha guardado.
    struct Slot {
        let id: UUID
        var date: Date?
        let isCompleted: Bool
        /// Conserva su fecha aunque incumpla la regla: los que van antes de un paso añadido no se tocan.
        var isFixed = false
    }

    /// Fecha final de cada paso pendiente con fecha, recorriendo el plan en orden.
    static func resolve(
        _ slots: [Slot],
        maxStepsPerDay: Int = maxStepsPerDay,
        calendar: Calendar = .current
    ) -> [UUID: Date] {
        var result: [UUID: Date] = [:]
        var previous: Date?
        var perDay: [DateComponents: Int] = [:]
        for slot in slots where !slot.isCompleted {
            guard var current = slot.date else { continue }
            if !slot.isFixed {
                if let previous, current < previous { current = previous }
                while perDay[day(of: current, calendar), default: 0] >= maxStepsPerDay,
                      let next = calendar.date(byAdding: .day, value: 1, to: current) {
                    current = next
                }
            }
            perDay[day(of: current, calendar), default: 0] += 1
            result[slot.id] = current
            previous = current
        }
        return result
    }

    private static func day(of date: Date, _ calendar: Calendar) -> DateComponents {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return DateComponents(year: c.year, month: c.month, day: c.day)
    }
}
