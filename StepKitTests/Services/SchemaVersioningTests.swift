import Foundation
import SwiftData
import Testing
@testable import StepKit

@Suite("SwiftData versioned schema", .serialized)
@MainActor
struct SchemaVersioningTests {
    /// Un almacén creado con el esquema sin versionar (TestFlight hasta la build 5)
    /// se abre con `StepKitSchemaV1` sin perder Kits ni pasos.
    @Test("Store created before versioning opens with V1 and keeps its data")
    func legacyStoreOpens() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "schema-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "default.store")
        let kitID = UUID()

        do {
            let legacy = Schema([GoalEntity.self, StepEntity.self, ProgressEntryEntity.self, WorkSessionEntity.self])
            let container = try ModelContainer(for: legacy, configurations: [ModelConfiguration(schema: legacy, url: url)])
            let context = container.mainContext
            let kit = GoalEntity(id: kitID, ownerID: "a", planTitle: "Correr 5 km", horizonDays: 30, kpi: "5 km")
            context.insert(kit)
            let step = StepEntity(ownerID: "a", stepTitle: "Caminar 20 min", descriptionShort: "", descriptionLong: "",
                                  estimateMinutes: 20)
            context.insert(step)
            kit.steps.append(step)
            context.insert(ProgressEntryEntity(ownerID: "a", kitID: kitID, stepID: step.id, kind: .progress,
                                               note: "Hecho", notedAt: .now, updatedAt: .now))
            try context.save()
        }

        let persistence = PersistenceController(storeURL: url)
        let reopened = persistence.container.mainContext
        let kits = try reopened.fetch(FetchDescriptor<GoalEntity>())
        #expect(kits.map(\.id) == [kitID])
        #expect(kits.first?.planTitle == "Correr 5 km")
        #expect(kits.first?.steps.map(\.stepTitle) == ["Caminar 20 min"])
        #expect(try reopened.fetchCount(FetchDescriptor<ProgressEntryEntity>()) == 1)
        withExtendedLifetime(persistence) {}
    }
}
