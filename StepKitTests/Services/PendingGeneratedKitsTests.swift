import Foundation
import SwiftData
import Testing
@testable import StepKit

@Suite("Generated plans left without accepting", .serialized)
@MainActor
struct PendingGeneratedKitsTests {
    @Test("A plan the server saved but the person never accepted becomes a tombstone; a saved one is kept")
    func leftoversAreDiscarded() throws {
        let persistence = PersistenceController(inMemory: true)
        let context = persistence.container.mainContext
        let abandoned = UUID()
        let accepted = UUID()
        for id in PendingGeneratedKits.all { PendingGeneratedKits.remove(id) }

        context.insert(GoalEntity(id: accepted, ownerID: "owner", planTitle: "Kept", horizonDays: 7, kpi: "",
                                  metaType: "", metaTags: [], risks: [], version: 1, progress: 0, sourceModel: nil,
                                  createdAt: .now, updatedAt: .now, deletedAt: nil, isDeleted: false))
        try context.save()
        PendingGeneratedKits.add(abandoned)
        PendingGeneratedKits.add(accepted)

        let changed = PendingGeneratedKits.discardLeftovers(ownerID: "owner", in: context)

        #expect(changed)
        #expect(PendingGeneratedKits.all.isEmpty)
        let kits = try context.fetch(FetchDescriptor<GoalEntity>())
        #expect(kits.first { $0.id == abandoned }?.isDeleted == true)
        #expect(kits.first { $0.id == accepted }?.isDeleted == false)
    }
}
