import Foundation
import Testing
@testable import StepKit

@Suite("Daily step reminders")
struct DailyDigestTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Madrid")!
        return calendar
    }

    private func date(_ day: Int, _ hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour))!
    }

    private func kit(created: Date, steps: [(String, Int)]) -> DailyDigest.KitInfo {
        DailyDigest.KitInfo(id: UUID(), title: "Pesto", createdAt: created,
                            steps: steps.map { DailyDigest.StepInfo(title: $0.0, days: [date($0.1)]) })
    }

    @Test("Several steps on the same day become one reminder, plus the eve and the day after")
    func oneReminderPerDay() {
        let items = DailyDigest.plan(kits: [kit(created: date(1, 8), steps: [("Reunir", 3), ("Triturar", 3), ("Servir", 3)])],
                                     now: date(1, 10), calendar: calendar)
        #expect(items.count == 3)
        #expect(items[0].fireDate == date(2, 9))
        #expect(items[0].body == DailyDigest.body(today: [], overdue: [], tomorrow: ["Reunir", "Triturar", "Servir"]))
        #expect(items[1].fireDate == date(3, 9))
        #expect(items[1].body == DailyDigest.body(today: ["Reunir", "Triturar", "Servir"], overdue: [], tomorrow: []))
        #expect(items[2].fireDate == date(4, 9))
        #expect(items[2].body == DailyDigest.body(today: [], overdue: ["Reunir", "Triturar", "Servir"], tomorrow: []))
    }

    @Test("A Kit for today created after 9:00 only gets the day-after reminder")
    func sameDayKitHasNoPastReminders() {
        let items = DailyDigest.plan(kits: [kit(created: date(1, 18), steps: [("Cocer", 1)])],
                                     now: date(1, 18), calendar: calendar)
        #expect(items.count == 1)
        #expect(items[0].fireDate == date(2, 9))
        #expect(items[0].body == DailyDigest.body(today: [], overdue: ["Cocer"], tomorrow: []))
    }

    @Test("The eve is skipped for a Kit created that same day, and can be turned off")
    func eveRules() {
        let createdToday = DailyDigest.plan(kits: [kit(created: date(1, 7), steps: [("Correr", 2)])],
                                            now: date(1, 7), calendar: calendar)
        #expect(createdToday.first?.body == DailyDigest.body(today: ["Correr"], overdue: [], tomorrow: []))
        let noEve = DailyDigest.plan(kits: [kit(created: date(1, 7), steps: [("Correr", 4)])],
                                     now: date(1, 10), includesDayBefore: false, calendar: calendar)
        #expect(noEve.map(\.fireDate) == [date(4, 9), date(5, 9)])
    }

    private func habit(created: Date = Date(timeIntervalSince1970: 0), done: [Int] = []) -> DailyDigest.KitInfo {
        DailyDigest.KitInfo(id: UUID(), title: "Oposición", createdAt: created, steps: [
            DailyDigest.StepInfo(title: "Fichas", days: (5...8).map { date($0) }, doneDays: done.map { date($0) })
        ])
    }

    @Test("A daily step only says today, whatever happened yesterday")
    func dailyStepSaysOnlyToday() {
        for done: [Int] in [[], [5]] {
            let items = DailyDigest.plan(kits: [habit(done: done)], now: date(5, 10), calendar: calendar)
            #expect(items.first { $0.fireDate == date(6, 9) }?.body == DailyDigest.body(today: ["Fichas"], overdue: [], tomorrow: []))
        }
    }

    @Test("A session already done takes the step out of that day's reminder")
    func doneSessionIsLeftOut() {
        let items = DailyDigest.plan(kits: [habit(done: [6])], now: date(5, 10), calendar: calendar)
        #expect(items.contains { $0.fireDate == date(6, 9) } == false)
        #expect(items.first { $0.fireDate == date(7, 9) }?.body == DailyDigest.body(today: ["Fichas"], overdue: [], tomorrow: []))
    }

    @Test("The eve and the day after only appear around the sessions")
    func eveAndDayAfterOfARepeatingStep() {
        let items = DailyDigest.plan(kits: [habit()], now: date(1, 10), calendar: calendar)
        #expect(items.first { $0.fireDate == date(4, 9) }?.body == DailyDigest.body(today: [], overdue: [], tomorrow: ["Fichas"]))
        #expect(items.first { $0.fireDate == date(9, 9) }?.body == DailyDigest.body(today: [], overdue: ["Fichas"], tomorrow: []))
        let lastDone = DailyDigest.plan(kits: [habit(done: [8])], now: date(1, 10), calendar: calendar)
        #expect(lastDone.contains { $0.fireDate == date(9, 9) } == false)
    }
}
