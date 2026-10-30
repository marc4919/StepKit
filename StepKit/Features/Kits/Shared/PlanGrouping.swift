//
//  PlanGrouping.swift
//  StepKit
//
//  La misma regla para el plan del Kit y para la vista previa al crear: cabeceras de sección por
//  semana contadas desde la primera fecha del plan, o por día cuando el plan cabe en dos semanas.
//

import Foundation

/// Grupo de pasos con su cabecera: una semana («Semana 2 · 7 – 13 nov») o, en planes de dos semanas o
/// menos, un día («Hoy», «Mañana», «Miércoles 4 nov»).
struct PlanGroup<Item> {
    let key: Int
    let title: String
    /// En un grupo diario las filas no repiten la fecha.
    let byDay: Bool
    let items: [Item]
}

enum PlanGrouping {
    static func groups<Item>(_ items: [Item], date: (Item) -> Date?,
                             calendar: Calendar = .current, now: Date = .now) -> [PlanGroup<Item>] {
        let days = items.compactMap { date($0).map { calendar.startOfDay(for: $0) } }
        guard let first = days.min(), let last = days.max() else {
            return items.isEmpty ? [] : [PlanGroup(key: 0, title: "", byDay: false, items: items)]
        }
        let byDay = (calendar.dateComponents([.day], from: first, to: last).day ?? 0) < 14
        var keyed: [(key: Int, items: [Item])] = []
        var undated: [Item] = []
        for item in items {
            guard let day = date(item).map({ calendar.startOfDay(for: $0) }) else {
                undated.append(item)
                continue
            }
            let offset = calendar.dateComponents([.day], from: first, to: day).day ?? 0
            let key = byDay ? offset : offset / 7
            if let index = keyed.firstIndex(where: { $0.key == key }) {
                keyed[index].items.append(item)
            } else {
                keyed.append((key, [item]))
            }
        }
        var groups = keyed.map { group -> PlanGroup<Item> in
            let start = calendar.date(byAdding: .day, value: byDay ? group.key : group.key * 7, to: first) ?? first
            let title = byDay ? dayTitle(start, calendar: calendar, now: now)
                              : weekTitle(number: group.key + 1, start: start, calendar: calendar)
            return PlanGroup(key: group.key, title: title, byDay: byDay, items: group.items)
        }
        if !undated.isEmpty {
            groups.append(PlanGroup(key: -1, title: String(localized: "Sin fecha"), byDay: false, items: undated))
        }
        return groups
    }

    /// «Hoy», «Mañana», «Ayer» o «Miércoles 4 nov».
    static func dayTitle(_ day: Date, calendar: Calendar = .current, now: Date = .now) -> String {
        if calendar.isDate(day, inSameDayAs: now) { return String(localized: "Hoy") }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(day, inSameDayAs: tomorrow) {
            return String(localized: "Mañana")
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(day, inSameDayAs: yesterday) {
            return String(localized: "Ayer")
        }
        let text = day.formatted(.dateTime.weekday(.wide).day().month(.abbreviated))
        return text.prefix(1).uppercased() + text.dropFirst()
    }

    /// «Semana 1 · 31 oct – 6 nov» o «Semana 2 · 7 – 13 nov».
    static func weekTitle(number: Int, start: Date, calendar: Calendar = .current) -> String {
        let end = calendar.date(byAdding: .day, value: 6, to: start) ?? start
        let range = calendar.isDate(start, equalTo: end, toGranularity: .month)
            ? "\(start.formatted(.dateTime.day())) – \(end.formatted(.dateTime.day().month(.abbreviated)))"
            : "\(start.formatted(.dateTime.day().month(.abbreviated))) – \(end.formatted(.dateTime.day().month(.abbreviated)))"
        return String(localized: "Semana \(number) · \(range)")
    }

    /// Fecha corta de una fila dentro de una semana: «Hoy» (destacada), «Mañana» o «mié 4».
    static func rowDate(_ date: Date, calendar: Calendar = .current, now: Date = .now) -> (text: String, isToday: Bool) {
        if calendar.isDate(date, inSameDayAs: now) { return (String(localized: "Hoy"), true) }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(date, inSameDayAs: tomorrow) {
            return (String(localized: "Mañana"), false)
        }
        return (date.formatted(.dateTime.weekday(.abbreviated).day()), false)
    }

    /// «8 pasos · 5 semanas · ≈ 5 h 45 min en total», con las repeticiones contadas y redondeado al cuarto de hora.
    static func summary(stepCount: Int, dates: [Date], totalMinutes: Int, calendar: Calendar = .current) -> String {
        var parts = [stepCount == 1 ? String(localized: "1 paso") : String(localized: "\(stepCount) pasos")]
        if let first = dates.min(), let last = dates.max() {
            let days = (calendar.dateComponents([.day], from: calendar.startOfDay(for: first), to: calendar.startOfDay(for: last)).day ?? 0) + 1
            let weeks = max(1, Int((Double(days) / 7).rounded(.up)))
            parts.append(weeks == 1 ? String(localized: "1 semana") : String(localized: "\(weeks) semanas"))
        }
        if totalMinutes > 0 {
            let minutes = totalMinutes >= 60 ? Int((Double(totalMinutes) / 15).rounded()) * 15 : totalMinutes
            let duration = Duration.seconds(minutes * 60).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
            parts.append(String(localized: "≈ \(duration) en total"))
        }
        return parts.joined(separator: " · ")
    }
}
