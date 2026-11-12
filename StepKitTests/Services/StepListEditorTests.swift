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

    @Test("A plan that all happens today says so")
    func summaryForToday() {
        let today = PlanGrouping.summary(stepCount: 3, dates: [.now, .now], totalMinutes: 0)
        #expect(today.contains(String(localized: "Hoy")))
        #expect(!today.contains(String(localized: "1 semana")))
        let later = Calendar.current.date(byAdding: .day, value: 9, to: .now) ?? .now
        #expect(PlanGrouping.summary(stepCount: 2, dates: [.now, later], totalMinutes: 0).contains(String(localized: "\(2) semanas")))
        let soon = Calendar.current.date(byAdding: .day, value: 2, to: .now) ?? .now
        let short = PlanGrouping.summary(stepCount: 2, dates: [.now, soon], totalMinutes: 0)
        #expect(short.contains(String(localized: "\(3) días")))
        #expect(!short.contains(String(localized: "1 semana")))
        let week = Calendar.current.date(byAdding: .day, value: 6, to: .now) ?? .now
        #expect(PlanGrouping.summary(stepCount: 2, dates: [.now, week], totalMinutes: 0).contains(String(localized: "1 semana")))
        #expect(PlanGrouping.summary(stepCount: 1, dates: [soon], totalMinutes: 0).contains(String(localized: "1 día")))
    }

    @Test("The original order comes back, and steps added later keep their place")
    func originalOrderRestores() {
        let a = UUID(), b = UUID(), c = UUID(), added = UUID()
        let positions = [a: 1, b: 2, c: 3]
        #expect(OriginalPlanOrder.restored([c, added, a, b], positions: positions) == [a, added, b, c])
        #expect(OriginalPlanOrder.restored([a, b, c], positions: positions) == [a, b, c])
        #expect(OriginalPlanOrder.restored([b, a], positions: [:]) == [b, a])
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

    @Test("Splitting keeps every part on the step's day and remembers the parts to open")
    func splitStaysOnTheSameDay() async throws {
        let kit = makeKit(["A", "B"])
        let b = try step("B", in: kit)
        b.suggestedDeadline = day(3)
        let change = ProposedStepChange(stepID: b.id, stepLabel: "Paso 2", from: nil, to: nil)
        let proposal = PlanProposal(title: "Dividir", changes: [change], impact: "",
                                    actions: [.split(stepID: b.id, titles: ["B1", "B2", "B3"], minutes: 10,
                                                     outcomes: ["Uno", "Dos", "Tres"], descriptions: ["Cómo uno", "Cómo dos", "Cómo tres"])])
        await proposal.accept(in: kit, context: context, highlights: ChangeHighlights())
        #expect(titles(kit) == ["A", "B1", "B2", "B3"])
        #expect(try step("B1", in: kit).descriptionShort == "Uno")
        #expect(try step("B3", in: kit).descriptionLong == "Cómo tres")
        for title in ["B1", "B2", "B3"] {
            #expect(Calendar.current.isDate(try step(title, in: kit).suggestedDeadline ?? .distantPast, inSameDayAs: day(3)))
        }
        let parts = try #require(proposal.changes.first?.partStepIDs)
        #expect(parts == ["B1", "B2", "B3"].compactMap { try? step($0, in: kit).id })
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
        #expect(added.changesPlanStructure)
        #expect(added.structureSummary.contains("Nuevo"))
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

    @Test("The assistant is told which steps really moved and which went, not the ones shifted by them")
    func draftStructureSummary() throws {
        let kit = makeKit(["Reunir", "Repasar", "Pesto", "Cocer"])
        var draft = StepListDraft(kit: kit)
        draft.movePending(fromOffsets: [2], toOffset: 0)
        draft.remove(try step("Cocer", in: kit).id)
        #expect(draft.structureSummary.contains("Pesto"))
        #expect(draft.structureSummary.contains("Cocer"))
        #expect(!draft.structureSummary.contains("Reunir"))
        #expect(!draft.structureSummary.contains("Repasar"))
    }

    @Test("The review request carries the changes and asks to check the order first")
    func reviewPromptIncludesChanges() {
        let kit = makeKit()
        let prompt = AssistantIntent.reviewChanges.prompt(kit: kit, planChanges: "CAMBIO-DE-PRUEBA")
        #expect(prompt.contains("CAMBIO-DE-PRUEBA"))
        #expect(prompt.contains(kit.title))
        #expect(prompt.count < 1_200)
    }

    @Test("The summary stays short enough for the server even with many changes")
    func structureSummaryIsBounded() {
        let kit = makeKit((1...60).map { "Paso con un título bastante largo número \($0)" })
        var draft = StepListDraft(kit: kit)
        draft.movePending(fromOffsets: IndexSet(0..<30), toOffset: 60)
        let message = AssistantIntent.reviewChanges.prompt(kit: kit, planChanges: draft.structureSummary)
        #expect(message.count <= 2_000)
    }

    @Test("A date chosen by hand is respected on a full day, and the steps moved around it keep the maximum")
    func draftRespectsChosenDate() throws {
        let kit = makeKit(["A", "B", "C", "D"])
        dated(kit, [5, 5, 5, 3])
        try step("D", in: kit).isCompleted = true
        var draft = StepListDraft(kit: kit)
        draft.add(StepDraft(title: "Disfrutar", date: day(5)))
        #expect(draft.dateChanges().isEmpty)
        draft.apply(to: kit, context: context)
        #expect(try offsets(kit)[titles(kit).firstIndex(of: "Disfrutar")!] == 5)
    }

    @Test("A date moved later by hand stays, and only the steps that would end up before it are pushed")
    func draftChosenLaterDate() throws {
        let kit = makeKit(["A", "B", "C"])
        dated(kit, [1, 2, 6])
        var draft = StepListDraft(kit: kit)
        var a = try #require(draft.pending.first)
        a.date = day(4)
        draft.update(a)
        #expect(draft.dateChanges().map(\.title) == ["B"])
        draft.apply(to: kit, context: context)
        #expect(offsets(kit) == [4, 4, 6])
    }

    @Test("A chosen date before the previous step is corrected, and the alert shows it")
    func draftChosenDateKeepsOrder() throws {
        let kit = makeKit(["A", "B"])
        dated(kit, [3, 6])
        var draft = StepListDraft(kit: kit)
        var b = try #require(draft.pending.last)
        b.date = day(1)
        draft.update(b)
        #expect(draft.dateChanges().map(\.title) == ["B"])
        draft.apply(to: kit, context: context)
        #expect(offsets(kit) == [3, 3])
    }

    @Test("The step editor respects its date on a full day; the assistant's moves keep the maximum")
    func rescheduleChosenVersusAssistant() throws {
        let kit = makeKit(["A", "B", "C", "D"])
        dated(kit, [5, 5, 5, 8])
        let d = try step("D", in: kit)
        // D va después de los otros tres: elegir el día 5 lo deja el cuarto de ese día.
        let target = day(5)
        let chosen = PlanReschedule.dates(for: kit.orderedActiveSteps, overrides: [d.id: target], overridesAreChosen: true)
        #expect(chosen[d.id].map { Calendar.current.isDate($0, inSameDayAs: target) } == true)
        let automatic = PlanReschedule.dates(for: kit.orderedActiveSteps, overrides: [d.id: target])
        #expect(automatic[d.id].map { Calendar.current.isDate($0, inSameDayAs: day(6)) } == true)
    }

    @Test("The review asks for a short answer when the order fits, with no fixed opening")
    func reviewPromptAsksForShortAnswer() {
        let prompt = AssistantIntent.reviewChanges.prompt(kit: makeKit(), planChanges: nil)
        #expect(prompt.contains("una o dos frases") || prompt.contains("one or two sentences"))
        #expect(!prompt.contains("Hay un problema de orden:") && !prompt.contains("There is an order problem:"))
    }

    // MARK: - El asistente propone reordenar

    @Test("A move proposal reorders the plan, shows the change and adjusts the moved step's date")
    func moveStepProposal() async throws {
        let kit = makeKit(["Pesto", "Reunir", "Repasar"])
        dated(kit, [1, 2, 3])
        let plan = try proposal(#"{"type":"move_step","stepNumber":1,"newPosition":3}"#, kit: kit)
        #expect(plan.changes.first?.symbol == "arrow.up.arrow.down")
        #expect(plan.changes.count == 2)   // el movimiento y su nueva fecha
        await accept(plan, in: kit)
        #expect(titles(kit) == ["Reunir", "Repasar", "Pesto"])
        #expect(orders(kit) == [0, 1, 2])
        #expect(offsets(kit) == [2, 3, 3])
    }

    @Test("Several moves use the original positions as slots; the rest fill the free ones in order")
    func severalMovesAsSlots() async throws {
        let kit = makeKit(["A", "B", "C", "D"])
        let plan = try proposal(#"{"type":"move_step","stepNumber":4,"newPosition":1},{"type":"move_step","stepNumber":1,"newPosition":3}"#, kit: kit)
        await accept(plan, in: kit)
        #expect(titles(kit) == ["D", "B", "A", "C"])
    }

    @Test("Completed steps keep their place when pending ones are moved around them")
    func moveKeepsCompletedInPlace() async throws {
        let kit = makeKit(["A", "Hecho", "C", "D"])
        try step("Hecho", in: kit).isCompleted = true
        let plan = try proposal(#"{"type":"move_step","stepNumber":4,"newPosition":1}"#, kit: kit)
        await accept(plan, in: kit)
        #expect(titles(kit) == ["D", "Hecho", "A", "C"])
    }

    @Test("Invalid moves are ignored: a completed step, its slot, out of range or a repeated position")
    func invalidMovesIgnored() throws {
        let kit = makeKit(["A", "Hecho", "C", "D"])
        try step("Hecho", in: kit).isCompleted = true
        let invalid = [
            #"{"type":"move_step","stepNumber":2,"newPosition":1}"#,
            #"{"type":"move_step","stepNumber":1,"newPosition":2}"#,
            #"{"type":"move_step","stepNumber":1,"newPosition":9}"#,
            #"{"type":"move_step","stepNumber":9,"newPosition":1}"#,
            #"{"type":"move_step","stepNumber":1}"#
        ]
        for change in invalid {
            let json = #"{"summary":"Cambio","changes":[\#(change)]}"#
            let remote = try JSONDecoder().decode(AssistResponse.Proposal.self, from: Data(json.utf8))
            #expect(RemoteProposalBuilder.build(remote, kit: kit) == nil)
        }
        let repeated = try proposal(#"{"type":"move_step","stepNumber":1,"newPosition":4},{"type":"move_step","stepNumber":3,"newPosition":4}"#, kit: kit)
        #expect(repeated.changes.filter { $0.symbol == "arrow.up.arrow.down" }.count == 1)
    }

    @Test("Accepting a move proposal on an edited plan never duplicates or loses steps")
    func moveWithEdit() async throws {
        let kit = makeKit(["A", "B", "C"])
        let plan = try proposal(#"{"type":"move_step","stepNumber":3,"newPosition":1},{"type":"edit_step","stepNumber":1,"newTitles":["A2"]}"#, kit: kit)
        await accept(plan, in: kit)
        #expect(titles(kit) == ["C", "A2", "B"])
        #expect(kit.steps.count == 3)
    }

    // MARK: - Crear Kits a mano

    private var gregorian: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Madrid")!
        return calendar
    }

    private func nov(_ day: Int, _ calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: 9))!
    }

    private func days(_ dates: [Date], _ calendar: Calendar) -> [Int] { dates.map { calendar.component(.day, from: $0) } }

    @Test("Free plan: two active Kits reach the limit; finished, removed, other owners or Pro don't")
    func manualFreeLimit() throws {
        let one = makeKit(["A"])
        #expect(!ManualKit.reachesFreeLimit(kits: [one], ownerID: "a", isPremium: false))
        let two = makeKit(["B"])
        #expect(ManualKit.reachesFreeLimit(kits: [one, two], ownerID: "a", isPremium: false))
        #expect(!ManualKit.reachesFreeLimit(kits: [one, two], ownerID: "a", isPremium: true))
        #expect(!ManualKit.reachesFreeLimit(kits: [one, two], ownerID: "otra", isPremium: false))
        two.orderedActiveSteps[0].isCompleted = true
        #expect(!ManualKit.reachesFreeLimit(kits: [one, two], ownerID: "a", isPremium: false))
        two.orderedActiveSteps[0].isCompleted = false
        two.markAsDeleted()
        #expect(!ManualKit.reachesFreeLimit(kits: [one, two], ownerID: "a", isPremium: false))
    }

    // MARK: - Crear los pasos yo

    @Test("An empty Kit keeps what was written in the creator, marked as manual, and is not finished")
    func emptyKitFromCreator() throws {
        let c = gregorian
        let kit = ManualKit.createEmpty(name: " Mi casa ", dueDate: nov(20, c), doneWhen: " Pintada ", obstacles: "El cansancio",
                                        startingPoint: "Sin pintura", stepMinutes: 45, ownerID: "a", context: context,
                                        calendar: c, at: nov(2, c))
        #expect(kit.title == "Mi casa")
        #expect(kit.kpi == "Pintada")
        #expect(kit.risks == ["El cansancio"])
        #expect(kit.sourceModel == StepListDraft.manualSource)
        #expect(kit.activeStepCount == 0)
        #expect(!kit.isCompleted)
        #expect(ManualKit.stepMinutes(for: kit) == 45)
        let kitID = kit.id
        let entries = try context.fetch(FetchDescriptor<ProgressEntryEntity>(predicate: #Predicate { $0.kitID == kitID }))
        #expect(entries.map(\.note) == ["Sin pintura"])
        #expect(ManualKit.reachesFreeLimit(kits: [kit, makeKit(["A"])], ownerID: "a", isPremium: false))
    }

    @Test("Without optional text an empty Kit adds no note or risk, and no minutes means the default")
    func emptyKitMinimal() throws {
        let c = gregorian
        let kit = ManualKit.createEmpty(name: "Pan", dueDate: nov(6, c), ownerID: "a", context: context, calendar: c, at: nov(2, c))
        #expect(kit.kpi.isEmpty && kit.risks.isEmpty)
        #expect(ManualKit.stepMinutes(for: kit) == 20)
        let kitID = kit.id
        #expect(try context.fetch(FetchDescriptor<ProgressEntryEntity>(predicate: #Predicate { $0.kitID == kitID })).isEmpty)
    }

    @Test("Steps without a chosen date spread up to the final date as more are added")
    func addStepSpreads() throws {
        let kit = ManualKit.createEmpty(name: "Pan", dueDate: day(8), ownerID: "a", context: context)
        ManualKit.addStep(StepDraft(title: "Uno", date: nil), to: kit, context: context)
        #expect(offsets(kit) == [0])
        ManualKit.addStep(StepDraft(title: "Dos", date: nil), to: kit, context: context)
        #expect(offsets(kit) == [0, 8])
        ManualKit.addStep(StepDraft(title: "Tres", date: nil), to: kit, context: context)
        #expect(titles(kit) == ["Uno", "Dos", "Tres"])
        #expect(offsets(kit) == [0, 4, 8])
        #expect(orders(kit) == [0, 1, 2])
    }

    @Test("A new final date spreads the undated steps again and leaves chosen dates alone")
    func finalDateChangeSpreads() throws {
        let kit = ManualKit.createEmpty(name: "Pan", dueDate: day(4), ownerID: "a", context: context)
        ManualKit.addStep(StepDraft(title: "Uno", date: day(2)), to: kit, context: context)
        ManualKit.addStep(StepDraft(title: "Dos", date: nil), to: kit, context: context)
        #expect(offsets(kit) == [2, 4])

        var draft = KitEditDraft(kit: kit)
        draft.targetDate = day(10)
        #expect(try draft.apply(to: kit, expectedOwnerID: "a"))
        ManualKit.finalDateChanged(of: kit)
        #expect(offsets(kit) == [2, 10])
    }

    @Test("A chosen date never moves, and the others spread around it")
    func addStepKeepsChosenDate() throws {
        let kit = ManualKit.createEmpty(name: "Pan", dueDate: day(8), ownerID: "a", context: context)
        ManualKit.addStep(StepDraft(title: "Uno", date: nil), to: kit, context: context)
        ManualKit.addStep(StepDraft(title: "Dos", date: day(4)), to: kit, context: context)
        #expect(offsets(kit) == [0, 4])
        ManualKit.addStep(StepDraft(title: "Tres", date: nil), to: kit, context: context)
        ManualKit.addStep(StepDraft(title: "Cuatro", date: nil), to: kit, context: context)
        #expect(offsets(kit) == [0, 4, 6, 8])
        #expect(ManualKit.lastFixedDate(of: kit).map { Calendar.current.isDate($0, inSameDayAs: day(4)) } == true)
    }

    @Test("A date changed by other means stops moving with the spread")
    func addStepRespectsLaterChange() throws {
        let kit = ManualKit.createEmpty(name: "Pan", dueDate: day(8), ownerID: "a", context: context)
        ManualKit.addStep(StepDraft(title: "Uno", date: nil), to: kit, context: context)
        let two = ManualKit.addStep(StepDraft(title: "Dos", date: nil), to: kit, context: context)
        two.suggestedDeadline = day(2)
        ManualKit.addStep(StepDraft(title: "Tres", date: nil), to: kit, context: context)
        #expect(offsets(kit) == [0, 2, 8])
    }

    @Test("A Kit with 60 steps keeps its order and never passes the final date")
    func addStepAtTheLimit() throws {
        let kit = ManualKit.createEmpty(name: "Pan", dueDate: day(10), ownerID: "a", context: context)
        for number in 1...StepListEditor.maxSteps {
            ManualKit.addStep(StepDraft(title: "Paso \(number)", date: nil), to: kit, context: context)
        }
        try context.save()
        #expect(kit.steps.count == StepListEditor.maxSteps)
        #expect(orders(kit) == Array(0..<StepListEditor.maxSteps))
        #expect(titles(kit).first == "Paso 1")
        #expect(titles(kit).last == "Paso 60")
        let spread = offsets(kit).compactMap { $0 }
        #expect(spread == spread.sorted())
        #expect(spread.first == 0)
        #expect(spread.last == 10)
    }

    @Test("Without days left, the steps share today")
    func addStepTightDates() throws {
        let kit = ManualKit.createEmpty(name: "Pan", dueDate: day(0), ownerID: "a", context: context)
        ManualKit.addStep(StepDraft(title: "Uno", date: nil), to: kit, context: context)
        ManualKit.addStep(StepDraft(title: "Dos", date: nil), to: kit, context: context)
        #expect(offsets(kit) == [0, 0])
    }

    @Test("The assistant's steps for an empty plan keep their order, also when they all say step 0")
    func assistantFillsEmptyPlan() async throws {
        let kit = ManualKit.createEmpty(name: "Pan", dueDate: day(9), ownerID: "a", context: context)
        let plan = try proposal(
            #"{"type":"add_step","stepNumber":0,"newDate":"\#(text(day(1)))","newTitles":["Uno"]},{"type":"add_step","stepNumber":0,"newDate":"\#(text(day(2)))","newTitles":["Dos"]},{"type":"add_step","stepNumber":0,"newTitles":["Tres"]}"#,
            kit: kit)
        await proposal_accept(plan, in: kit)
        #expect(titles(kit) == ["Uno", "Dos", "Tres"])
        #expect(offsets(kit) == [1, 2, 2])
        #expect(kit.steps.count == 3)
    }

    private func proposal_accept(_ plan: PlanProposal, in kit: GoalEntity) async {
        await plan.accept(in: kit, context: context, highlights: ChangeHighlights(), pause: .zero, animation: nil)
    }
}
