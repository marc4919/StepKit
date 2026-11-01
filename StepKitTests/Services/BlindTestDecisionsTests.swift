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
