//
//  ManualKit.swift
//  StepKit
//
//  Crear un Kit a mano: nombre y fecha final; los pasos se añaden en el propio Kit. Sin IA, sin permiso de IA y sin gastar usos.
//

import SwiftData
import SwiftUI
import TipKit

/// Lo que no depende de la pantalla: límite del plan gratis y guardar el Kit.
enum ManualKit {
    /// Mismo criterio que el servidor al generar con IA: Kits activos, sin contar borrados ni terminados.
    static func reachesFreeLimit(kits: [GoalEntity], ownerID: String, isPremium: Bool) -> Bool {
        guard !isPremium else { return false }
        return kits.filter { $0.ownerID == ownerID && !$0.isRemoved && !$0.isCompleted }.count >= PlanLimits.freeActiveKits
    }

    /// Kit sin pasos, con lo escrito en el creador: los pasos se añaden después en el propio Kit.
    @discardableResult
    static func createEmpty(
        name: String,
        dueDate: Date,
        doneWhen: String = "",
        obstacles: String = "",
        startingPoint: String = "",
        stepMinutes: Int? = nil,
        ownerID: String,
        context: ModelContext,
        calendar: Calendar = .current,
        at now: Date = Date()
    ) -> GoalEntity {
        let due = calendar.startOfDay(for: dueDate)
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: due).day ?? 0
        let kit = GoalEntity(ownerID: ownerID, planTitle: name.trimmingCharacters(in: .whitespacesAndNewlines),
                             horizonDays: max(days + 1, 1), kpi: "", sourceModel: StepListDraft.manualSource,
                             createdAt: now, updatedAt: now)
        kit.targetDate = due
        context.insert(kit)
        kit.kpi = doneWhen.trimmingCharacters(in: .whitespacesAndNewlines)
        let obstacle = obstacles.trimmingCharacters(in: .whitespacesAndNewlines)
        if !obstacle.isEmpty { kit.risks = [obstacle] }
        if let stepMinutes { setStepMinutes(stepMinutes, for: kit) }
        try? context.save()
        KitCreationHints.kitCreated()
        try? ProgressLog.addKitNote(startingPoint, kit: kit, context: context, now: now)
        StartFromScratchTip().invalidate(reason: .actionPerformed)
        return kit
    }

    /// Tiempo con el que nacen los pasos de un Kit a mano: el que se eligió en el creador. Se guarda en
    /// este dispositivo porque es solo un valor inicial, y no merece un campo sincronizado.
    private static func stepMinutesKey(_ kit: GoalEntity) -> String { "manualKitStepMinutes.\(kit.id)" }

    static func setStepMinutes(_ minutes: Int, for kit: GoalEntity) {
        UserDefaults.standard.set(minutes, forKey: stepMinutesKey(kit))
    }

    static func stepMinutes(for kit: GoalEntity) -> Int {
        let saved = UserDefaults.standard.integer(forKey: stepMinutesKey(kit))
        return saved > 0 ? saved : kit.orderedActiveSteps.last?.estimateMinutes ?? 20
    }

    /// Añade un paso al final de un Kit ya creado. Sin fecha elegida, se reparte hasta la fecha final con
    /// los demás que tampoco la eligieron.
    @discardableResult
    static func addStep(
        _ step: StepDraft,
        to kit: GoalEntity,
        context: ModelContext,
        calendar: Calendar = .current,
        at now: Date = Date()
    ) -> StepEntity {
        let date = step.date ?? noon(now, calendar) ?? now
        let new = StepListEditor.insert(id: step.id, title: step.title, minutes: step.minutes, date: date,
                                        short: step.short, long: step.long, into: kit, context: context, at: now)
        var spread = spreadDates(of: kit, calendar: calendar)
        if step.date == nil { spread[new.id.uuidString] = date.timeIntervalSince1970 }
        setSpreadDates(spread, of: kit)
        redistribute(kit, calendar: calendar, at: now)
        return new
    }

    /// Con otra fecha final, los pasos que no eligieron día se reparten de nuevo; los demás no se mueven.
    static func finalDateChanged(of kit: GoalEntity, calendar: Calendar = .current, at now: Date = Date()) {
        redistribute(kit, calendar: calendar, at: now)
    }

    /// Último día que un paso nuevo con fecha elegida debe respetar: el de los pasos que no se mueven solos.
    static func lastFixedDate(of kit: GoalEntity, calendar: Calendar = .current) -> Date? {
        let spread = spreadDates(of: kit, calendar: calendar)
        return kit.orderedActiveSteps.last { !$0.isCompleted && spread[$0.id.uuidString] == nil }?.suggestedDeadline
    }

    /// Fecha que el reparto dio a cada paso. Se guarda en este dispositivo, sin campo sincronizado: en
    /// otro dispositivo esos pasos simplemente no se mueven.
    private static func spreadDatesKey(_ kit: GoalEntity) -> String { "manualKitSpreadDates.\(kit.id)" }

    private static func setSpreadDates(_ dates: [String: TimeInterval], of kit: GoalEntity) {
        UserDefaults.standard.set(dates, forKey: spreadDatesKey(kit))
    }

    /// Solo los que conservan esa fecha: si cambió por otra vía (a mano, el asistente, otro dispositivo),
    /// ya es una fecha elegida y no se toca.
    private static func spreadDates(of kit: GoalEntity, calendar: Calendar) -> [String: TimeInterval] {
        let saved = UserDefaults.standard.dictionary(forKey: spreadDatesKey(kit)) as? [String: TimeInterval] ?? [:]
        return saved.filter { id, time in
            guard let step = kit.orderedActiveSteps.first(where: { $0.id.uuidString == id }), !step.isCompleted,
                  let date = step.suggestedDeadline else { return false }
            return calendar.isDate(date, inSameDayAs: Date(timeIntervalSince1970: time))
        }
    }

    /// Cada tramo de pasos sin fecha elegida se reparte entre el paso fijo anterior (u hoy) y el siguiente
    /// (o la fecha final). La fecha final manda sobre `PlanReschedule.maxStepsPerDay`.
    private static func redistribute(_ kit: GoalEntity, calendar: Calendar, at now: Date) {
        guard let target = kit.targetDate else { return }
        var spread = spreadDates(of: kit, calendar: calendar)
        let pending = kit.orderedActiveSteps.filter { !$0.isCompleted }
        let today = calendar.startOfDay(for: now)
        var start = pending.startIndex
        while start < pending.endIndex {
            guard spread[pending[start].id.uuidString] != nil else {
                start += 1
                continue
            }
            let end = pending[start...].firstIndex { spread[$0.id.uuidString] == nil } ?? pending.endIndex
            let before = start > pending.startIndex ? pending[start - 1].suggestedDeadline : nil
            let after = end < pending.endIndex ? pending[end].suggestedDeadline : nil
            let first = max(today, before.map(calendar.startOfDay(for:)) ?? today)
            let last = max(first, calendar.startOfDay(for: after ?? target))
            let days = calendar.dateComponents([.day], from: first, to: last).day ?? 0
            // Un paso fijo ya ocupa su día: el tramo se reparte entre los dos, sin contarlo.
            let lead = before == nil ? 0 : 1
            let gaps = max(end - start - 1 + lead + (after == nil ? 0 : 1), 1)
            for (index, step) in pending[start..<end].enumerated() {
                guard let day = calendar.date(byAdding: .day, value: days * (index + lead) / gaps, to: first),
                      let date = noon(day, calendar) else { continue }
                spread[step.id.uuidString] = date.timeIntervalSince1970
                if let current = step.suggestedDeadline, calendar.isDate(current, inSameDayAs: date) { continue }
                step.suggestedDeadline = date
                step.markModified(at: now)
            }
            start = end
        }
        setSpreadDates(spread, of: kit)
    }

    private static func noon(_ date: Date, _ calendar: Calendar) -> Date? {
        calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date)
    }
}
