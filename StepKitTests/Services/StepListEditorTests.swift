import Foundation
import SwiftData
import Testing
@testable import StepKit

@Suite("Step list editor keeps steps numbered 0…n", .serialized)
@MainActor
struct StepListEditorTests {
    private let persistence = PersistenceController(inMemory: true)
    private var context: ModelContext { persistence.container.mainContext }

    private func makeKit(_ titles: [String] = ["A", "B", "C"], orders: [Int]? = nil) -> GoalEntity {
        let kit = GoalEntity(ownerID: "a", planTitle: "Kit", horizonDays: 7, kpi: "")
        context.insert(kit)
        for (index, title) in titles.enumerated() {
            let step = StepEntity(ownerID: "a", stepTitle: title, descriptionShort: "", descriptionLong: "",
                                  estimateMinutes: 10, suggestedDeadline: nil, effortLevel: "medium",
                                  order: orders?[index] ?? index)
            context.insert(step)
            kit.steps.append(step)
        }
        return kit
    }

    private func titles(_ kit: GoalEntity) -> [String] { kit.orderedActiveSteps.map(\.stepTitle) }
    private func orders(_ kit: GoalEntity) -> [Int] { kit.orderedActiveSteps.map(\.order) }

    private func step(_ title: String, in kit: GoalEntity) throws -> StepEntity {
        try #require(kit.orderedActiveSteps.first { $0.stepTitle == title })
    }

    @Test("Inserting at the start, in the middle and at the end keeps 0…n")
    func insertPositions() throws {
        let kit = makeKit()
        StepListEditor.insert(title: "Inicio", minutes: 5, date: nil, atStart: true, into: kit, context: context)
        #expect(titles(kit) == ["Inicio", "A", "B", "C"])
        StepListEditor.insert(title: "Medio", minutes: 5, date: nil, after: try step("A", in: kit), into: kit, context: context)
        #expect(titles(kit) == ["Inicio", "A", "Medio", "B", "C"])
        StepListEditor.insert(title: "Fin", minutes: 5, date: nil, into: kit, context: context)
        #expect(titles(kit) == ["Inicio", "A", "Medio", "B", "C", "Fin"])
        #expect(orders(kit) == Array(0...5))
    }

    @Test("An inserted step appears once, also after saving")
    func insertDoesNotDuplicate() throws {
        let kit = makeKit()
        let new = StepListEditor.insert(title: "Nuevo", minutes: 5, date: nil, into: kit, context: context)
        try context.save()
        #expect(kit.steps.filter { $0.id == new.id }.count == 1)
        #expect(new.goal?.id == kit.id)
        #expect(kit.activeStepCount == 4)
    }

    @Test("A step inserted after another inherits its date and effort unless it has its own date")
    func insertInherits() throws {
        let kit = makeKit()
        let anchor = try step("A", in: kit)
        let day = Date(timeIntervalSince1970: 1_800_000_000)
        anchor.suggestedDeadline = day
        anchor.effortLevel = "high"
        let inherited = StepListEditor.insert(title: "X", minutes: 5, date: nil, after: anchor, into: kit, context: context)
        #expect(inherited.suggestedDeadline == day)
        #expect(inherited.effortLevel == "high")
        let other = day.addingTimeInterval(86_400)
        let own = StepListEditor.insert(title: "Y", minutes: 5, date: other, after: anchor, into: kit, context: context)
        #expect(own.suggestedDeadline == other)
    }

    @Test("Removing a step closes the gap and keeps it as a soft delete")
    func removeClosesGap() throws {
        let kit = makeKit()
        let target = try step("B", in: kit)
        StepListEditor.remove(target, from: kit)
        #expect(titles(kit) == ["A", "C"])
        #expect(orders(kit) == [0, 1])
        #expect(target.deletedAt != nil)
        #expect(kit.steps.contains { $0.id == target.id })
    }

    @Test("Moving a step keeps 0…n in both directions and clamps the index")
    func moveBothWays() throws {
        let kit = makeKit(["A", "B", "C", "D"])
        StepListEditor.move(try step("A", in: kit), to: 2, in: kit)
        #expect(titles(kit) == ["B", "C", "A", "D"])
        StepListEditor.move(try step("D", in: kit), to: 0, in: kit)
        #expect(titles(kit) == ["D", "B", "C", "A"])
        StepListEditor.move(try step("D", in: kit), to: 99, in: kit)
        #expect(titles(kit) == ["B", "C", "A", "D"])
        #expect(orders(kit) == [0, 1, 2, 3])
    }

    @Test("Moving a removed step does nothing")
    func moveRemovedStep() throws {
        let kit = makeKit()
        let target = try step("B", in: kit)
        StepListEditor.remove(target, from: kit)
        StepListEditor.move(target, to: 0, in: kit)
        #expect(titles(kit) == ["A", "C"])
    }

    @Test("Renumbering repairs gaps and repeats from older Kits without changing their sequence")
    func renumberRepairsOldOrders() {
        let kit = makeKit(["A", "B", "C"], orders: [1, 4, 4])
        let before = titles(kit)
        StepListEditor.renumber(kit)
        #expect(titles(kit) == before)
        #expect(orders(kit) == [0, 1, 2])
    }

    @Test("Only steps whose order changes are marked as modified")
    func renumberMarksOnlyChanges() throws {
        let kit = makeKit(["A", "B", "C"])
        let first = try step("A", in: kit)
        let last = try step("C", in: kit)
        let firstDate = first.updatedAt
        let lastDate = last.updatedAt
        StepListEditor.remove(try step("B", in: kit), from: kit, at: Date().addingTimeInterval(60))
        #expect(first.updatedAt == firstDate)
        #expect(last.updatedAt > lastDate)
    }

    @Test("Dates spread from the first day to the last, in order")
    func distributeSpreads() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Madrid")!
        let kit = makeKit(["A", "B", "C", "D", "E"])
        let start = calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 16))!
        let end = calendar.date(from: DateComponents(year: 2026, month: 11, day: 10))!
        StepListEditor.distributeDates(of: kit.orderedActiveSteps, from: start, to: end, calendar: calendar)
        let days = kit.orderedActiveSteps.map { calendar.component(.day, from: $0.suggestedDeadline!) }
        #expect(days == [2, 4, 6, 8, 10])
    }

    @Test("More steps than days stay inside the range, and one step or a past end date don't break")
    func distributeEdgeCases() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Madrid")!
        let start = calendar.date(from: DateComponents(year: 2026, month: 11, day: 2))!
        let end = calendar.date(from: DateComponents(year: 2026, month: 11, day: 4))!

        let crowded = makeKit((1...10).map(String.init))
        StepListEditor.distributeDates(of: crowded.orderedActiveSteps, from: start, to: end, calendar: calendar)
        let days = crowded.orderedActiveSteps.map { calendar.component(.day, from: $0.suggestedDeadline!) }
        #expect(days == days.sorted())
        #expect(days.first == 2 && days.last == 4)

        let single = makeKit(["A"])
        StepListEditor.distributeDates(of: single.orderedActiveSteps, from: start, to: end, calendar: calendar)
        #expect(calendar.component(.day, from: single.orderedActiveSteps[0].suggestedDeadline!) == 2)

        let past = makeKit(["A", "B"])
        StepListEditor.distributeDates(of: past.orderedActiveSteps, from: end, to: start, calendar: calendar)
        #expect(past.orderedActiveSteps.allSatisfy { calendar.component(.day, from: $0.suggestedDeadline!) == 4 })
    }

    @Test("Accepting an assistant proposal adds, splits and removes as before, keeping 0…n")
    func assistantProposalUsesEditor() async throws {
        let kit = makeKit(["A", "B", "C"])
        let a = try step("A", in: kit)
        let b = try step("B", in: kit)
        let c = try step("C", in: kit)
        let proposal = PlanProposal(title: "Cambios", changes: [], impact: "", actions: [
            .add(afterStepID: a.id, atStart: false, title: "Nuevo", minutes: 5, date: nil, outcome: "Hecho", description: nil),
            .split(stepID: b.id, titles: ["B1", "B2"], minutes: 15),
            .remove(stepID: c.id),
            .add(afterStepID: nil, atStart: true, title: "Primero", minutes: 5, date: nil, outcome: nil, description: nil)
        ])
        let highlights = ChangeHighlights()
        await proposal.accept(in: kit, context: context, highlights: highlights)

        #expect(titles(kit) == ["Primero", "A", "Nuevo", "B1", "B2"])
        #expect(orders(kit) == Array(0...4))
        #expect(c.deletedAt != nil)
        #expect(kit.steps.count == Set(kit.steps.map(\.id)).count)
        let added = try step("Nuevo", in: kit)
        #expect(added.descriptionShort == "Hecho")
        #expect(highlights.kinds[added.id] == .added)
        #expect(try step("B2", in: kit).estimateMinutes == 15)
        #expect(proposal.state == .accepted)
    }
}
