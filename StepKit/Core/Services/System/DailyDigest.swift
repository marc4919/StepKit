//
//  DailyDigest.swift
//  StepKit
//
//  Un solo aviso al día por Kit, a la hora elegida (9:00 por defecto). Junta, por orden:
//  lo de hoy, lo que se quedó pendiente ayer (solo el día siguiente) y, si se quiere, lo de mañana.
//  Los pasos no tienen hora: el aviso a una hora concreta lo dan las sesiones reservadas.
//

import Foundation

enum DailyDigest {
    static let hourKey = "reminderHour"
    static let minuteKey = "reminderMinute"
    static let dayBeforeKey = "reminderDayBefore"
    static let identifierPrefix = "digest-"
    /// iOS guarda como mucho 64 avisos pendientes por app; se deja sitio para las sesiones.
    static let maxPending = 48
    static let daysAhead = 14

    struct Item: Equatable {
        let identifier: String
        let fireDate: Date
        let title: String
        let body: String
        let kitID: UUID
    }

    /// Un paso tal como lo necesita el resumen: título, días en que toca y si sigue pendiente.
    struct StepInfo {
        let title: String
        let days: [Date]
    }

    struct KitInfo {
        let id: UUID
        let title: String
        let createdAt: Date
        let steps: [StepInfo]
    }

    static func plan(
        kits: [KitInfo],
        now: Date,
        hour: Int = 9,
        minute: Int = 0,
        includesDayBefore: Bool = true,
        calendar: Calendar = .current
    ) -> [Item] {
        let today = calendar.startOfDay(for: now)
        var items: [Item] = []
        for kit in kits {
            for offset in 0...daysAhead {
                guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                      let fire = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day),
                      fire > now,
                      let yesterday = calendar.date(byAdding: .day, value: -1, to: day),
                      let tomorrow = calendar.date(byAdding: .day, value: 1, to: day) else { continue }
                let due = titles(kit.steps, on: day, calendar)
                let overdue = titles(kit.steps, on: yesterday, calendar)
                // La víspera solo si el Kit ya existía antes de ese día: si se crea hoy para mañana, sobra.
                let next = includesDayBefore && kit.createdAt < day ? titles(kit.steps, on: tomorrow, calendar) : []
                guard let body = body(today: due, overdue: overdue, tomorrow: next) else { continue }
                items.append(Item(
                    identifier: identifierPrefix + kit.id.uuidString + "-" + dayKey(day, calendar),
                    fireDate: fire, title: kit.title, body: body, kitID: kit.id))
            }
        }
        return Array(items.sorted { $0.fireDate < $1.fireDate }.prefix(maxPending))
    }

    /// Lo de hoy primero; luego lo pendiente de ayer y lo de mañana. nil si no hay nada.
    static func body(today: [String], overdue: [String], tomorrow: [String]) -> String? {
        var lines: [String] = []
        if let first = today.first {
            lines.append(today.count == 1 ? String(localized: "Hoy: \(first)")
                         : String(localized: "Hoy: \(first) y \(today.count - 1) más"))
        }
        if let first = overdue.first {
            lines.append(overdue.count == 1 ? String(localized: "Se quedó pendiente: \(first). ¿Lo haces hoy o lo mueves?")
                         : String(localized: "Se quedaron pendientes: \(first) y \(overdue.count - 1) más"))
        }
        if let first = tomorrow.first {
            lines.append(tomorrow.count == 1 ? String(localized: "Mañana: \(first)")
                         : String(localized: "Mañana: \(tomorrow.count) pasos"))
        }
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }

    private static func titles(_ steps: [StepInfo], on day: Date, _ calendar: Calendar) -> [String] {
        steps.filter { $0.days.contains { calendar.isDate($0, inSameDayAs: day) } }.map(\.title)
    }

    private static func dayKey(_ day: Date, _ calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: day)
        return String(format: "%04d%02d%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

extension DailyDigest.KitInfo {
    /// Solo cuentan los pasos pendientes con recordatorio y fecha; un hábito toca cada día de su repetición.
    init(_ kit: GoalEntity) {
        let steps: [DailyDigest.StepInfo] = kit.orderedActiveSteps.compactMap { step in
            guard !step.isCompleted, step.notificationEnabled, let first = step.suggestedDeadline else { return nil }
            let days = step.repetition?.dates(from: first) ?? [first]
            return DailyDigest.StepInfo(title: step.stepTitle, days: days)
        }
        self.init(id: kit.id, title: kit.title, createdAt: kit.createdAt, steps: steps)
    }
}
