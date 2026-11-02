import Foundation
import Testing
@testable import StepKit

@Suite("Date choice in the creator and the end-date warning")
@MainActor
struct BlindTestDecisionsTests {
    @Test("The creator starts with no date and needs one to prepare a plan")
    func noDefaultDate() {
        let vm = KitCreatorViewModel(apiClient: MockAPIClient())
        vm.description = "Correr 10 km"
        #expect(vm.dueDate == nil)
        #expect(!vm.isFormValid)
        vm.dueDate = Calendar.current.date(byAdding: .month, value: 1, to: .now)
        #expect(vm.isFormValid)
        vm.dueDate = Calendar.current.startOfDay(for: .now)
        #expect(vm.isFormValid)   // hoy sigue siendo elegible, para un Kit de una sesión
    }

    @Test("A goal of only spaces cannot prepare a plan and is not a draft to protect")
    func onlySpaces() {
        let vm = KitCreatorViewModel(apiClient: MockAPIClient())
        vm.dueDate = Calendar.current.date(byAdding: .month, value: 1, to: .now)
        vm.description = "   \n "
        #expect(!vm.isFormValid)
        #expect(!vm.hasDraft)
        vm.doneWhen = "Correr sin parar"
        #expect(vm.hasDraft)
    }

    @Test("From the Calendar, today is not a choice but another selected day is")
    func calendarDate() {
        #expect(KitCreatorViewModel(apiClient: MockAPIClient(), initialDate: .now).dueDate == nil)
        let later = Calendar.current.date(byAdding: .day, value: 10, to: .now)!
        #expect(KitCreatorViewModel(apiClient: MockAPIClient(), initialDate: later).dueDate == later)
    }

    @Test("A new session never defaults to the small hours")
    func sessionStart() {
        let calendar = Calendar.current
        func at(_ hour: Int) -> Date { calendar.date(bySettingHour: hour, minute: 30, second: 0, of: Date(timeIntervalSince1970: 1_900_000_000))! }
        let night = at(0)
        let start = SessionStart.default(on: night, now: night)
        #expect(calendar.component(.hour, from: start) == 9)
        #expect(calendar.isDate(start, inSameDayAs: night))
        let late = at(23)
        let next = SessionStart.default(on: late, now: late)
        #expect(calendar.component(.hour, from: next) == 9)
        #expect(!calendar.isDate(next, inSameDayAs: late))
        let afternoon = at(16)
        #expect(calendar.component(.hour, from: SessionStart.default(on: afternoon, now: afternoon)) == 17)
    }

    @Test("Discarded proposals reach the assistant in the conversation summary")
    func discardedProposals() {
        #expect(AssistRequestBuilder.summary(nil, discarded: []) == nil)
        #expect(AssistRequestBuilder.summary("Resumen.", discarded: []) == "Resumen.")
        let withBase = AssistRequestBuilder.summary("Resumen.", discarded: ["Mover el paso 3"])
        #expect(withBase?.hasPrefix("Resumen. ") == true)
        #expect(withBase?.contains("«Mover el paso 3»") == true)
        #expect(AssistRequestBuilder.summary(nil, discarded: ["Dividir"])?.contains("«Dividir»") == true)
    }

    @Test("A proposal with the same changes as a discarded one counts as repeated, however it is worded")
    func repeatedProposal() {
        let step = UUID()
        let day = Date(timeIntervalSince1970: 1_900_000_000)
        let kit = GoalEntity(ownerID: "a", planTitle: "Kit", horizonDays: 30, kpi: "")
        let conversation = KitAssistantStore.shared.newConversation(kit: kit, title: "Prueba")
        let first = PlanProposal(title: "Mover el paso", changes: [], impact: "", actions: [.setDate(stepID: step, date: day)])
        conversation.add(first)
        let same = PlanProposal(title: "Otro título", changes: [], impact: "Otro impacto",
                                actions: [.setDate(stepID: step, date: day.addingTimeInterval(60))])
        #expect(!conversation.wasDiscarded(same))   // aún pendiente, no descartada
        first.state = .discarded
        #expect(conversation.wasDiscarded(same))
        let otherDay = PlanProposal(title: "Mover el paso", changes: [], impact: "",
                                    actions: [.setDate(stepID: step, date: day.addingTimeInterval(86_400 * 2))])
        #expect(!conversation.wasDiscarded(otherDay))
    }

    @Test("The warning appears only when a moved step passes the Kit's end date")
    func endDateWarning() {
        let target = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_900_000_000))
        let day = 86_400.0
        #expect(!PlanReschedule.passes(target: target, moves: [:]))
        #expect(!PlanReschedule.passes(target: target, moves: [UUID(): target.addingTimeInterval(3_600)]))
        #expect(!PlanReschedule.passes(target: target, moves: [UUID(): target.addingTimeInterval(-day)]))
        #expect(PlanReschedule.passes(target: target, moves: [UUID(): target.addingTimeInterval(day)]))
    }
}
