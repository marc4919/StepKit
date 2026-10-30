import Foundation
import SwiftData
import Testing
@testable import StepKit

/// `GoalEntity.isDeleted` choca con `PersistentModel.isDeleted`: leído desde Swift tras guardar
/// devuelve `false`. Estos tests fijan que el estado se lee con `isRemoved` y viaja bien al sync.
@Suite("Kit soft delete survives saving and reaches sync", .serialized)
@MainActor
struct KitSoftDeleteTests {
    @Test("A Kit deleted and saved still reads as deleted and syncs deleted=true with its date")
    func deletedKitSyncsAsDeleted() throws {
        let persistence = PersistenceController(inMemory: true)
        let context = persistence.container.mainContext
        let kit = GoalEntity(ownerID: "a", planTitle: "Kit", horizonDays: 7, kpi: "")
        let alive = GoalEntity(ownerID: "a", planTitle: "Vivo", horizonDays: 7, kpi: "")
        context.insert(kit)
        context.insert(alive)
        try context.save()

        kit.markAsDeleted()
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<GoalEntity>())
        let deleted = try #require(fetched.first { $0.id == kit.id })
        #expect(deleted.isRemoved)
        let dto = deleted.toSyncDTO()
        #expect(dto.deleted)
        #expect(dto.deletedAt != nil)   // el servidor rechaza deletedAt sin deleted=true

        let other = try #require(fetched.first { $0.id == alive.id })
        #expect(!other.isRemoved)
        #expect(!other.toSyncDTO().deleted)
        #expect(other.toSyncDTO().deletedAt == nil)

        let visible = try context.fetch(FetchDescriptor<GoalEntity>(predicate: #Predicate { !$0.isDeleted }))
        #expect(visible.map(\.id) == [alive.id])
        withExtendedLifetime(persistence) {}
    }

    @Test("A Kit created deleted without a date gets one, so it never syncs half-deleted")
    func deletedWithoutDateGetsOne() throws {
        let kit = GoalEntity(ownerID: "a", planTitle: "Kit", horizonDays: 7, kpi: "", isDeleted: true)
        #expect(kit.deletedAt != nil)
        #expect(kit.toSyncDTO().deleted)
    }
}
