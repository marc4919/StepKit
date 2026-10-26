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

    /// Fechas nuevas de los pasos pendientes tras aplicar `overrides` (id → fecha deseada).
    /// Devuelve solo los pasos cuyo día cambia, incluidos los de `overrides`.
    static func dates(
        for steps: [StepEntity],
        overrides: [UUID: Date],
        maxStepsPerDay: Int = maxStepsPerDay,
        calendar: Calendar = .current
    ) -> [UUID: Date] {
        var result: [UUID: Date] = [:]
        var previous: Date?
        var perDay: [DateComponents: Int] = [:]
        for step in steps where !step.isCompleted {
            guard var current = overrides[step.id] ?? step.suggestedDeadline else { continue }
            if let previous, current < previous { current = previous }
            while perDay[day(of: current, calendar), default: 0] >= maxStepsPerDay,
                  let next = calendar.date(byAdding: .day, value: 1, to: current) {
                current = next
            }
            perDay[day(of: current, calendar), default: 0] += 1
            let original = step.suggestedDeadline
            if original == nil || !calendar.isDate(original!, inSameDayAs: current) {
                result[step.id] = current
            }
            previous = current
        }
        return result
    }

    private static func day(of date: Date, _ calendar: Calendar) -> DateComponents {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return DateComponents(year: c.year, month: c.month, day: c.day)
    }
}
