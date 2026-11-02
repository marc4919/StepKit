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
        StepListEditor.remove(target, from: kit, context: context)
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
        StepListEditor.remove(target, from: kit, context: context)
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
        StepListEditor.remove(try step("B", in: kit), from: kit, context: context, at: Date().addingTimeInterval(60))
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

    // MARK: - Fechas de los pasos que añade el asistente

    private func day(_ offset: Int, from today: Date = Calendar.current.startOfDay(for: Date())) -> Date {
        Calendar.current.date(bySettingHour: 12, minute: 0, second: 0,
                              of: Calendar.current.date(byAdding: .day, value: offset, to: today)!)!
    }

    private func proposal(_ changes: String, impact: String = "El resto no cambia", kit: GoalEntity) throws -> PlanProposal {
        let json = #"{"summary":"Cambio","impact":"\#(impact)","changes":[\#(changes)]}"#
        let remote = try JSONDecoder().decode(AssistResponse.Proposal.self, from: Data(json.utf8))
        return try #require(RemoteProposalBuilder.build(remote, kit: kit))
    }

    private func text(_ date: Date) -> String { AssistRequestBuilder.day(date)! }

    private func accept(_ proposal: PlanProposal, in kit: GoalEntity) async {
        await proposal.accept(in: kit, context: context, highlights: ChangeHighlights())
    }

    private func dated(_ kit: GoalEntity, _ dates: [Int]) {
        for (step, offset) in zip(kit.orderedActiveSteps, dates) { step.suggestedDeadline = day(offset) }
    }

    private func offsets(_ kit: GoalEntity) -> [Int?] {
        let today = Calendar.current.startOfDay(for: Date())
        return kit.orderedActiveSteps.map { step in
            step.suggestedDeadline.flatMap { Calendar.current.dateComponents([.day], from: today, to: Calendar.current.startOfDay(for: $0)).day }
        }
    }

    @Test("A new step can't land before the previous one, and the rest stays put when there's room")
    func addedStepKeepsOrder() async throws {
        let kit = makeKit(["A", "B", "C"])
        dated(kit, [1, 2, 3])
        let plan = try proposal(#"{"type":"add_step","stepNumber":1,"newDate":"\#(text(day(0)))","newTitles":["Nuevo"]}"#, kit: kit)
        #expect(plan.impact == "El resto no cambia")
        #expect(plan.changes.count == 1)
        await accept(plan, in: kit)
        #expect(titles(kit) == ["A", "Nuevo", "B", "C"])
        #expect(offsets(kit) == [1, 1, 2, 3])
    }

    @Test("A later date pushes only the steps that would end up before it, and the card shows them")
    func addedStepPushesFollowers() async throws {
        let kit = makeKit(["A", "B", "C"])
        dated(kit, [1, 2, 6])
        let plan = try proposal(#"{"type":"add_step","stepNumber":1,"newDate":"\#(text(day(4)))","newTitles":["Nuevo"]}"#, kit: kit)
        #expect(plan.changes.count == 2)
        #expect(plan.impact == String(localized: "Otros pasos se mueven para mantener el orden."))
        await accept(plan, in: kit)
        #expect(offsets(kit) == [1, 4, 4, 6])
    }

    @Test("A full day pushes the new step to the next one")
    func addedStepRespectsDailyMaximum() async throws {
        let kit = makeKit(["A", "B", "C", "D"])
        dated(kit, [1, 1, 1, 5])
        let plan = try proposal(#"{"type":"add_step","stepNumber":3,"newDate":"\#(text(day(1)))","newTitles":["Nuevo"]}"#, kit: kit)
        await accept(plan, in: kit)
        #expect(offsets(kit) == [1, 1, 1, 2, 5])
    }

    @Test("Without a date, a new step takes the previous step's, or the first one's at the start")
    func addedStepWithoutDate() async throws {
        let kit = makeKit(["A", "B"])
        dated(kit, [2, 4])
        let plan = try proposal(#"{"type":"add_step","stepNumber":1,"newTitles":["Medio"]},{"type":"add_step","stepNumber":0,"newTitles":["Inicio"]}"#, kit: kit)
        await accept(plan, in: kit)
        #expect(titles(kit) == ["Inicio", "A", "Medio", "B"])
        #expect(offsets(kit) == [2, 2, 2, 4])
    }

    @Test("Steps before the new one keep their dates even if they were already out of order")
    func addedStepLeavesEarlierStepsAlone() async throws {
        let kit = makeKit(["A", "B", "C"])
        dated(kit, [5, 2, 7])
        let plan = try proposal(#"{"type":"add_step","stepNumber":2,"newDate":"\#(text(day(3)))","newTitles":["Nuevo"]}"#, kit: kit)
        await accept(plan, in: kit)
        #expect(offsets(kit) == [5, 2, 3, 7])
    }

    @Test("Going past the Kit's final date is stated in the proposal")
    func addedStepPastFinalDate() throws {
        let kit = makeKit(["A", "B"])
        dated(kit, [1, 2])
        kit.targetDate = day(3)
        let plan = try proposal(#"{"type":"add_step","stepNumber":2,"newDate":"\#(text(day(5)))","newTitles":["Nuevo"]}"#, kit: kit)
        #expect(plan.impact == String(localized: "Algún paso quedaría después de la fecha final del Kit, el \(day(3).formatted(.dateTime.day().month(.wide)))."))
    }

    @Test("Moving a step works as before: the plan keeps its order")
    func moveProposalUnchanged() async throws {
        let kit = makeKit(["A", "B", "C"])
        dated(kit, [1, 2, 3])
        let plan = try proposal(#"{"type":"move_step_date","stepNumber":1,"newDate":"\#(text(day(4)))"}"#, kit: kit)
        #expect(plan.impact == "El resto no cambia")
        await accept(plan, in: kit)
        #expect(titles(kit) == ["A", "B", "C"])
        #expect(offsets(kit) == [4, 4, 4])
    }

    // MARK: - Fase 2: borrar con sesiones y fechas al mover

    private func session(for step: StepEntity, in kit: GoalEntity) -> WorkSessionEntity {
        let session = WorkSessionEntity(ownerID: "a", kitID: kit.id, stepID: step.id, startsAt: day(2),
                                        durationMinutes: 30, reminderEnabled: false)
        context.insert(session)
        return session
    }

    @Test("Removing a step moves its sessions to the Kit; other steps' sessions stay")
    func removeDetachesSessions() throws {
        let kit = makeKit()
        let a = try step("A", in: kit)
        let b = try step("B", in: kit)
        let own = session(for: b, in: kit)
        let other = session(for: a, in: kit)
        #expect(StepListEditor.sessions(of: b, in: kit, context: context).count == 1)
        let before = own.updatedAt
        let detached = StepListEditor.remove(b, from: kit, context: context, at: Date().addingTimeInterval(60))
        #expect(detached.map(\.id) == [own.id])
        #expect(own.stepID == nil)
        #expect(own.kitID == kit.id)
        #expect(own.deletedAt == nil)
        #expect(own.updatedAt > before)
        #expect(other.stepID == a.id)
    }

    @Test("An already deleted session isn't counted or touched")
    func removeIgnoresDeletedSessions() throws {
        let kit = makeKit()
        let b = try step("B", in: kit)
        let gone = session(for: b, in: kit)
        gone.markAsDeleted()
        #expect(StepListEditor.sessions(of: b, in: kit, context: context).isEmpty)
        #expect(StepListEditor.remove(b, from: kit, context: context).isEmpty)
        #expect(gone.stepID == b.id)
    }

    @Test("Removing through the assistant also moves the step's sessions to the Kit")
    func assistantRemoveDetachesSessions() async throws {
        let kit = makeKit()
        let b = try step("B", in: kit)
        let own = session(for: b, in: kit)
        let plan = PlanProposal(title: "Quitar", changes: [], impact: "", actions: [.remove(stepID: b.id)])
        await accept(plan, in: kit)
        #expect(own.stepID == nil)
    }

    private func moveSettling(_ title: String, to index: Int, in kit: GoalEntity) throws {
        let target = try step(title, in: kit)
        StepListEditor.move(target, to: index, in: kit)
        StepListEditor.settleDate(of: target, in: kit)
    }

    @Test("A step moved later takes the previous step's date and the rest stay")
    func moveLaterTakesPreviousDate() throws {
        let kit = makeKit(["A", "B", "C", "D"])
        dated(kit, [1, 2, 3, 4])
        try moveSettling("A", to: 2, in: kit)
        #expect(titles(kit) == ["B", "C", "A", "D"])
        #expect(offsets(kit) == [2, 3, 3, 4])
    }

    @Test("A step moved to the start takes the next step's date")
    func moveToStartTakesNextDate() throws {
        let kit = makeKit(["A", "B", "C"])
        dated(kit, [1, 2, 3])
        try moveSettling("C", to: 0, in: kit)
        #expect(titles(kit) == ["C", "A", "B"])
        #expect(offsets(kit) == [1, 1, 2])
    }

    @Test("A date that already fits between its neighbours doesn't change")
    func moveKeepsFittingDate() throws {
        let kit = makeKit(["A", "B", "C"])
        dated(kit, [2, 2, 2])
        try moveSettling("C", to: 1, in: kit)
        #expect(offsets(kit) == [2, 2, 2])
    }

    @Test("Moving into a full day pushes the moved step and later steps only as needed")
    func moveIntoFullDay() throws {
        let kit = makeKit(["A", "B", "C", "D", "E"])
        dated(kit, [1, 1, 1, 2, 9])
        try moveSettling("E", to: 3, in: kit)
        #expect(titles(kit) == ["A", "B", "C", "E", "D"])
        #expect(offsets(kit) == [1, 1, 1, 2, 2])
    }

    @Test("Completed steps keep their dates and don't count as neighbours")
    func moveIgnoresCompletedSteps() throws {
        let kit = makeKit(["A", "B", "C"])
        dated(kit, [8, 2, 3])
        try step("A", in: kit).isCompleted = true
        try moveSettling("C", to: 1, in: kit)
        #expect(titles(kit) == ["A", "C", "B"])
        #expect(offsets(kit) == [8, 2, 2])
    }

    @Test("Settling a step in a Kit without dates leaves it without a date")
    func settleWithoutDates() throws {
        let kit = makeKit()
        StepListEditor.settleDate(of: try step("B", in: kit), in: kit)
        #expect(offsets(kit) == [nil, nil, nil])
    }

    // MARK: - Borrador de la hoja «Editar pasos»

    @Test("Nothing changes in the Kit until the draft is applied")
    func draftDoesNotTouchKit() throws {
        let kit = makeKit()
        dated(kit, [1, 2, 3])
        var draft = StepListDraft(kit: kit)
        #expect(!draft.hasChanges)
        draft.movePending(fromOffsets: [0], toOffset: 3)
        draft.remove(try step("B", in: kit).id)
        draft.add(StepDraft(title: "Nuevo", date: day(5)))
        #expect(draft.hasChanges)
        #expect(titles(kit) == ["A", "B", "C"])
        #expect(offsets(kit) == [1, 2, 3])
    }

    @Test("Applying adds, removes and reorders; the order stays 0…n and a new step appears once")
    func draftApply() throws {
        let kit = makeKit(["A", "B", "C"])
        dated(kit, [1, 2, 3])
        let b = try step("B", in: kit)
        var draft = StepListDraft(kit: kit)
        draft.remove(b.id)
        draft.add(StepDraft(title: "  Nuevo  ", short: "Hecho", minutes: 45, date: day(7)))
        draft.apply(to: kit, context: context)
        try context.save()
        #expect(titles(kit) == ["A", "C", "Nuevo"])
        #expect(orders(kit) == [0, 1, 2])
        #expect(offsets(kit) == [1, 3, 7])
        #expect(b.deletedAt != nil)
        let new = try step("Nuevo", in: kit)
        #expect(new.descriptionShort == "Hecho" && new.estimateMinutes == 45)
        #expect(kit.steps.filter { $0.id == new.id }.count == 1)
    }

    @Test("A moved step takes the previous step's date, and the change is shown before saving")
    func draftMoveDates() throws {
        let kit = makeKit(["A", "B", "C", "D"])
        dated(kit, [1, 2, 3, 4])
        var draft = StepListDraft(kit: kit)
        draft.movePending(fromOffsets: [0], toOffset: 3)
        let changes = draft.dateChanges()
        #expect(changes.map(\.title) == ["A"])
        draft.apply(to: kit, context: context)
        #expect(titles(kit) == ["B", "C", "A", "D"])
        #expect(offsets(kit) == [2, 3, 3, 4])
    }

    @Test("Moving to the start takes the next date; moving back to the same place changes nothing")
    func draftMoveToStartAndBack() throws {
        let kit = makeKit(["A", "B", "C"])
        dated(kit, [1, 2, 3])
        var draft = StepListDraft(kit: kit)
        draft.movePending(fromOffsets: [2], toOffset: 0)
        #expect(draft.dateChanges().map(\.title) == ["C"])
        var same = draft
        same.movePending(fromOffsets: [0], toOffset: 3)
        #expect(!same.hasChanges)
        #expect(same.dateChanges().isEmpty)
        draft.apply(to: kit, context: context)
        #expect(offsets(kit) == [1, 1, 2])
    }

    @Test("Removing or renaming doesn't move dates; a chosen date that fits is respected")
    func draftKeepsDates() throws {
        let kit = makeKit(["A", "B", "C"])
        dated(kit, [1, 2, 3])
        var draft = StepListDraft(kit: kit)
        draft.remove(try step("B", in: kit).id)
        var a = try #require(draft.pending.first)
        a.title = "A2"
        draft.update(a)
        draft.add(StepDraft(title: "Fin", date: day(9)))
        #expect(draft.dateChanges().isEmpty)
        draft.apply(to: kit, context: context)
        #expect(titles(kit) == ["A2", "C", "Fin"])
        #expect(offsets(kit) == [1, 3, 9])
    }

    @Test("A new step's earlier date is corrected and shown; a later date pushes only what's needed")
    func draftNewStepDates() throws {
        let kit = makeKit(["A", "B"])
        dated(kit, [3, 8])
        var draft = StepListDraft(kit: kit)
        draft.add(StepDraft(title: "Nuevo", date: day(1)))
        #expect(draft.dateChanges().map(\.title) == ["Nuevo"])
        draft.apply(to: kit, context: context)
        #expect(offsets(kit) == [3, 8, 8])
    }

    @Test("Completed steps keep their place and date when the pending ones are reordered")
    func draftKeepsCompletedInPlace() throws {
        let kit = makeKit(["A", "B", "C", "D"])
        dated(kit, [8, 1, 2, 3])
        try step("A", in: kit).isCompleted = true
        var draft = StepListDraft(kit: kit)
        #expect(draft.completed.map(\.title) == ["A"])
        draft.movePending(fromOffsets: [2], toOffset: 0)
        draft.apply(to: kit, context: context)
        #expect(titles(kit) == ["A", "D", "B", "C"])
        #expect(offsets(kit) == [8, 1, 1, 2])
        #expect(orders(kit) == [0, 1, 2, 3])
    }

    @Test("Plan structure changes only when an existing step moves or goes")
    func draftStructure() throws {
        let kit = makeKit()
        var added = StepListDraft(kit: kit)
        added.add(StepDraft(title: "Nuevo", date: nil))
        #expect(!added.changesPlanStructure)
        added.remove(try #require(added.pending.last).id)
        #expect(!added.changesPlanStructure)
        #expect(!added.hasChanges)

        var moved = StepListDraft(kit: kit)
        moved.movePending(fromOffsets: [0], toOffset: 2)
        #expect(moved.changesPlanStructure)

        var removed = StepListDraft(kit: kit)
        removed.remove(try step("A", in: kit).id)
        #expect(removed.changesPlanStructure)
    }

    @Test("Removing through the draft moves the step's sessions to the Kit")
    func draftRemoveDetachesSessions() throws {
        let kit = makeKit()
        let b = try step("B", in: kit)
        let own = session(for: b, in: kit)
        var draft = StepListDraft(kit: kit)
        draft.remove(b.id)
        #expect(own.stepID == b.id)
        let detached = draft.apply(to: kit, context: context)
        #expect(detached.map(\.id) == [own.id])
        #expect(own.stepID == nil)
    }

    @Test("Going past the Kit's final date is detected")
    func draftPassesTarget() throws {
        let kit = makeKit(["A"])
        dated(kit, [1])
        var draft = StepListDraft(kit: kit)
        #expect(!draft.passes(target: day(3)))
        draft.add(StepDraft(title: "Nuevo", date: day(5)))
        #expect(draft.passes(target: day(3)))
    }
}
