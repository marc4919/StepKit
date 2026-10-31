import Foundation
import SwiftData
import Testing
@testable import StepKit

@Suite("Kit target date is stored, synced and kept")
@MainActor
struct KitTargetDateTests {
    private let day = Date(timeIntervalSince1970: 1_900_000_000)

    @Test("The chosen date wins over the last step and travels in the sync payload")
    func targetDateIsTheDueDate() throws {
        let kit = GoalEntity(ownerID: "a", planTitle: "Kit", horizonDays: 30, kpi: "")
        let step = StepEntity(ownerID: "a", stepTitle: "Paso", descriptionShort: "", descriptionLong: "",
                              estimateMinutes: 10, suggestedDeadline: day.addingTimeInterval(-86_400 * 5))
        kit.steps.append(step)
        #expect(kit.dueDate == step.suggestedDeadline)
        kit.targetDate = day
        #expect(kit.dueDate == day)
        #expect(kit.toSyncDTO().targetDate == day)
    }

    @Test("A server that does not send the date keeps the local one; one that sends it updates it")
    func serverWithoutDateKeepsLocal() throws {
        let kit = GoalEntity(ownerID: "a", planTitle: "Kit", horizonDays: 30, kpi: "")
        kit.targetDate = day
        var dto = kit.toSyncDTO()
        dto.targetDate = nil
        kit.update(from: dto)
        #expect(kit.targetDate == day)

        let later = day.addingTimeInterval(86_400 * 7)
        dto.targetDate = later
        kit.update(from: dto)
        #expect(kit.targetDate == later)
        #expect(GoalEntity(fromSync: dto, ownerID: "a").targetDate == later)
    }

    @Test("The payload omits the date when the Kit has none, so older servers are unaffected")
    func payloadOmitsMissingDate() throws {
        let kit = GoalEntity(ownerID: "a", planTitle: "Kit", horizonDays: 30, kpi: "")
        let json = String(decoding: try JSONEncoder().encode(kit.toSyncDTO()), as: UTF8.self)
        #expect(!json.contains("targetDate"))
        let decoded = try JSONDecoder().decode(KitSyncDTO.self, from: Data(json.utf8))
        #expect(decoded.targetDate == nil)
    }
}
