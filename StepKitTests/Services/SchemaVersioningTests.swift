import Foundation
import SwiftData
import Testing
@testable import StepKit

@Suite("SwiftData versioned schema", .serialized)
@MainActor
struct SchemaVersioningTests {
    private func tempStoreURL() throws -> (URL, URL) {
        let folder = FileManager.default.temporaryDirectory.appending(path: "schema-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return (folder, folder.appending(path: "default.store"))
    }

    /// Un almacén de TestFlight (esquema V1, sin fecha final) se migra a V2 sin perder nada.
    @Test("V1 store migrates to V2 and keeps Kits, steps and progress")
    func v1StoreMigrates() throws {
        let (folder, url) = try tempStoreURL()
        defer { try? FileManager.default.removeItem(at: folder) }
        let kitID = UUID()

        do {
            let v1 = Schema(versionedSchema: StepKitSchemaV1.self)
            let container = try ModelContainer(for: v1, configurations: [ModelConfiguration(schema: v1, url: url)])
            let context = container.mainContext
            let kit = StepKitSchemaV1.GoalEntity()
            kit.id = kitID
            kit.ownerID = "a"
            kit.planTitle = "Correr 5 km"
            context.insert(kit)
            let step = StepKitSchemaV1.StepEntity()
            step.stepTitle = "Caminar 20 min"
            step.suggestedDeadline = Date(timeIntervalSince1970: 1_800_000_000)
            context.insert(step)
            kit.steps.append(step)
            let entry = StepKitSchemaV1.ProgressEntryEntity()
            entry.kitID = kitID
            entry.kindRaw = "progress"
            context.insert(entry)
            try context.save()
        }

        let persistence = PersistenceController(storeURL: url)
        let reopened = persistence.container.mainContext
        let kits = try reopened.fetch(FetchDescriptor<GoalEntity>())
        #expect(kits.map(\.id) == [kitID])
        let kit = try #require(kits.first)
        #expect(kit.planTitle == "Correr 5 km")
        #expect(kit.steps.map(\.stepTitle) == ["Caminar 20 min"])
        #expect(kit.targetDate == nil)
        #expect(kit.dueDate == Date(timeIntervalSince1970: 1_800_000_000))   // sin fecha guardada, la del último paso
        #expect(try reopened.fetchCount(FetchDescriptor<ProgressEntryEntity>()) == 1)

        let target = Date(timeIntervalSince1970: 1_900_000_000)
        kit.targetDate = target
        try reopened.save()
        #expect(kit.dueDate == target)
        withExtendedLifetime(persistence) {}
    }
}
