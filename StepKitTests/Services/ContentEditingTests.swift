import Foundation
import SwiftData
import Testing
@testable import StepKit

@Suite("Kit and Step content editing", .serialized)
@MainActor
struct ContentEditingTests {
    @Test("Kit edits are normalized and versioned")
    func kitEditIsNormalizedAndVersioned() throws {
        let initialDate = Date(timeIntervalSince1970: 1_700_000_000)
        let editDate = initialDate.addingTimeInterval(60)
        let kit = GoalEntity(
            ownerID: "account-a",
            planTitle: "Original Kit",
            horizonDays: 30,
            kpi: "Original KPI",
            version: 4,
            updatedAt: initialDate
        )

        let changed = try KitEditDraft(
            title: "  Edited Kit  ",
            kpi: "  Edited KPI\n"
        ).apply(to: kit, expectedOwnerID: "account-a", at: editDate)

        #expect(changed)
        #expect(kit.planTitle == "Edited Kit")
        #expect(kit.kpi == "Edited KPI")
        #expect(kit.version == 5)
        #expect(kit.updatedAt == editDate)
        #expect(kit.toSyncDTO().title == "Edited Kit")
        #expect(kit.toSyncDTO().kpi == "Edited KPI")
    }

    @Test("A semantic no-op does not advance Kit metadata")
    func kitNoOpDoesNotAdvanceMetadata() throws {
        let initialDate = Date(timeIntervalSince1970: 1_700_000_000)
        let kit = GoalEntity(
            ownerID: "account-a",
            planTitle: "Stable Kit",
            horizonDays: 30,
            kpi: "Stable KPI",
            version: 3,
            updatedAt: initialDate
        )

        let changed = try KitEditDraft(
            title: " Stable Kit ",
            kpi: "Stable KPI\n"
        ).apply(
            to: kit,
            expectedOwnerID: "account-a",
            at: initialDate.addingTimeInterval(60)
        )

        #expect(!changed)
        #expect(kit.version == 3)
        #expect(kit.updatedAt == initialDate)
    }

    @Test("Kit editing rejects empty required content")
    func kitEditingRejectsEmptyContent() {
        let kit = GoalEntity(
            ownerID: "account-a",
            planTitle: "Kit",
            horizonDays: 7,
            kpi: "KPI"
        )

        #expect(throws: ContentEditingError.emptyKitTitle) {
            try KitEditDraft(title: " \n", kpi: "KPI")
                .apply(to: kit, expectedOwnerID: "account-a")
        }
        #expect(throws: ContentEditingError.emptyKitKPI) {
            try KitEditDraft(title: "Kit", kpi: "\t")
                .apply(to: kit, expectedOwnerID: "account-a")
        }
    }

    @Test("Step edits update the Step and its parent Kit exactly once")
    func stepEditUpdatesStepAndParent() throws {
        let initialDate = Date(timeIntervalSince1970: 1_700_000_000)
        let editDate = initialDate.addingTimeInterval(60)
        let kit = GoalEntity(
            ownerID: "account-a",
            planTitle: "Kit",
            horizonDays: 30,
            kpi: "KPI",
            version: 7,
            updatedAt: initialDate
        )
        let step = StepEntity(
            ownerID: "account-a",
            stepTitle: "Original Step",
            descriptionShort: "Original short",
            descriptionLong: "Original long",
            estimateMinutes: 20,
            updatedAt: initialDate
        )
        step.goal = kit

        let changed = try StepEditDraft(
            title: "  Edited Step ",
            shortDescription: " Edited short ",
            longDescription: " Edited long\n"
        ).apply(to: step, expectedOwnerID: "account-a", at: editDate)

        #expect(changed)
        #expect(step.stepTitle == "Edited Step")
        #expect(step.descriptionShort == "Edited short")
        #expect(step.descriptionLong == "Edited long")
        #expect(step.updatedAt == editDate)
        #expect(kit.updatedAt == editDate)
        #expect(kit.version == 8)
        #expect(step.toSyncDTO().title == "Edited Step")
        #expect(step.toSyncDTO().descriptionShort == "Edited short")
        #expect(step.toSyncDTO().descriptionLong == "Edited long")
    }

    @Test("Step editing requires a title but preserves optional descriptions")
    func stepEditingValidatesOnlyRequiredContent() throws {
        let kit = GoalEntity(
            ownerID: "account-a",
            planTitle: "Kit",
            horizonDays: 7,
            kpi: "KPI"
        )
        let step = makeStep()
        step.goal = kit

        #expect(throws: ContentEditingError.emptyStepTitle) {
            try StepEditDraft(
                title: " ",
                shortDescription: "Short",
                longDescription: "Long"
            ).apply(to: step, expectedOwnerID: "account-a")
        }

        let changed = try StepEditDraft(
            title: "Renamed Step",
            shortDescription: "\n",
            longDescription: "\t"
        ).apply(to: step, expectedOwnerID: "account-a")
        #expect(changed)
        #expect(step.stepTitle == "Renamed Step")
        #expect(step.descriptionShort.isEmpty)
        #expect(step.descriptionLong.isEmpty)
    }

    @Test("Editors reject cross-account, deleted and stale entities")
    func editorsRejectUnsafeTargets() throws {
        let kit = GoalEntity(
            ownerID: "account-a",
            planTitle: "Kit",
            horizonDays: 7,
            kpi: "KPI",
            version: 1,
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        #expect(throws: ContentEditingError.ownerMismatch) {
            try KitEditDraft(title: "Changed", kpi: "KPI")
                .apply(to: kit, expectedOwnerID: "account-b")
        }

        kit.markAsDeleted()
        #expect(throws: ContentEditingError.deletedContent) {
            try KitEditDraft(title: "Changed", kpi: "KPI")
                .apply(to: kit, expectedOwnerID: "account-a")
        }

        let freshKit = GoalEntity(
            ownerID: "account-a",
            planTitle: "Fresh",
            horizonDays: 7,
            kpi: "KPI",
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        var staleDraft = KitEditDraft(kit: freshKit)
        staleDraft.title = "Local edit"
        freshKit.markModified(at: Date(timeIntervalSince1970: 1_700_000_100))
        #expect(throws: ContentEditingError.staleContent) {
            try staleDraft.apply(to: freshKit, expectedOwnerID: "account-a")
        }
    }

    @Test("Step editor rejects unsafe targets")
    func stepEditorRejectsUnsafeTargets() {
        let ownerKit = makeKit(ownerID: "account-a")
        let crossAccountStep = makeStep(ownerID: "account-a")
        crossAccountStep.goal = ownerKit
        #expect(throws: ContentEditingError.ownerMismatch) {
            try StepEditDraft(title: "Changed", shortDescription: "", longDescription: "")
                .apply(to: crossAccountStep, expectedOwnerID: "account-b")
        }

        let deletedStep = makeStep(ownerID: "account-a")
        deletedStep.goal = makeKit(ownerID: "account-a")
        deletedStep.deletedAt = Date()
        #expect(throws: ContentEditingError.deletedContent) {
            try StepEditDraft(title: "Changed", shortDescription: "", longDescription: "")
                .apply(to: deletedStep, expectedOwnerID: "account-a")
        }

        let orphanedStep = makeStep(ownerID: "account-a")
        #expect(throws: ContentEditingError.missingParentKit) {
            try StepEditDraft(title: "Changed", shortDescription: "", longDescription: "")
                .apply(to: orphanedStep, expectedOwnerID: "account-a")
        }

        let deletedParent = makeKit(ownerID: "account-a")
        deletedParent.markAsDeleted()
        let childOfDeletedParent = makeStep(ownerID: "account-a")
        childOfDeletedParent.goal = deletedParent
        #expect(throws: ContentEditingError.deletedContent) {
            try StepEditDraft(title: "Changed", shortDescription: "", longDescription: "")
                .apply(to: childOfDeletedParent, expectedOwnerID: "account-a")
        }

        let staleStep = makeStep(ownerID: "account-a")
        staleStep.goal = makeKit(ownerID: "account-a")
        var staleDraft = StepEditDraft(step: staleStep)
        staleDraft.title = "Local edit"
        staleStep.markModified(at: staleStep.updatedAt.addingTimeInterval(60))
        #expect(throws: ContentEditingError.staleContent) {
            try staleDraft.apply(to: staleStep, expectedOwnerID: "account-a")
        }
    }

    @Test("Local editing timestamps remain monotonic")
    func editingTimestampsRemainMonotonic() throws {
        let futureDate = Date(timeIntervalSince1970: 1_800_000_000)
        let olderLocalDate = Date(timeIntervalSince1970: 1_700_000_000)
        let kit = GoalEntity(
            ownerID: "account-a",
            planTitle: "Kit",
            horizonDays: 7,
            kpi: "KPI",
            updatedAt: futureDate
        )

        _ = try KitEditDraft(title: "Edited", kpi: "KPI")
            .apply(to: kit, expectedOwnerID: "account-a", at: olderLocalDate)

        #expect(kit.updatedAt > futureDate)

        let deletionBaseline = kit.updatedAt
        kit.markAsDeleted(at: olderLocalDate)
        #expect(kit.updatedAt > deletionBaseline)
        #expect(kit.deletedAt == kit.updatedAt)
    }

    @Test("Edited Kit and Step content is included in the next sync batch")
    func editedContentIsIncludedInSync() async throws {
        let initialDate = Date(timeIntervalSince1970: 1_700_000_000)
        let editDate = initialDate.addingTimeInterval(60)
        let cutoff = initialDate.addingTimeInterval(30)
        let persistence = PersistenceController(inMemory: true)
        let context = persistence.container.mainContext
        let kit = GoalEntity(
            ownerID: "account-a",
            planTitle: "Original Kit",
            horizonDays: 30,
            kpi: "Original KPI",
            updatedAt: initialDate
        )
        let step = makeStep(ownerID: "account-a", updatedAt: initialDate)
        step.goal = kit
        context.insert(kit)
        context.insert(step)
        try context.save()

        _ = try KitEditDraft(title: "Synced Kit", kpi: "Synced KPI")
            .apply(to: kit, expectedOwnerID: "account-a", at: editDate)
        _ = try StepEditDraft(
            title: "Synced Step",
            shortDescription: "Synced short",
            longDescription: "Synced long"
        ).apply(to: step, expectedOwnerID: "account-a", at: editDate)
        try context.save()

        let suiteName = "StepKitTests.ContentEditing.\(UUID().uuidString)"
        let preferences = try #require(UserDefaults(suiteName: suiteName))
        defer { preferences.removePersistentDomain(forName: suiteName) }
        let authManager = makeAuthenticatedManager()
        let network = ContentEditingSyncNetworkService()
        let service = SyncService(
            authManager: authManager,
            networkService: network,
            preferences: preferences,
            now: { cutoff }
        )
        service.configure(with: context)
        service.lastSyncDate = initialDate

        try await service.syncAll()

        let request = try #require(network.lastRequest)
        let syncedKit = try #require(request.kits.first { $0.id == kit.id })
        let syncedStep = try #require(request.steps.first { $0.id == step.id })
        #expect(syncedKit.title == "Synced Kit")
        #expect(syncedKit.kpi == "Synced KPI")
        #expect(syncedStep.title == "Synced Step")
        #expect(syncedStep.descriptionShort == "Synced short")
        #expect(syncedStep.descriptionLong == "Synced long")
        #expect(service.lastSyncDate == cutoff)
    }

    private func makeStep(
        ownerID: String = "account-a",
        updatedAt: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) -> StepEntity {
        StepEntity(
            ownerID: ownerID,
            stepTitle: "Step",
            descriptionShort: "Short",
            descriptionLong: "Long",
            estimateMinutes: 20,
            updatedAt: updatedAt
        )
    }

    private func makeKit(ownerID: String) -> GoalEntity {
        GoalEntity(
            ownerID: ownerID,
            planTitle: "Kit",
            horizonDays: 7,
            kpi: "KPI",
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    private func makeAuthenticatedManager() -> AuthManager {
        let manager = AuthManager(keychain: ContentEditingKeychainStore())
        manager.saveAuth(
            token: "token-account-a",
            user: UserInfo(
                id: "account-a",
                tier: "premium",
                monthlyTokensUsed: 0,
                monthlyTokenQuota: 10_000
            )
        )
        return manager
    }
}

@MainActor
private final class ContentEditingSyncNetworkService: SyncNetworkServicing {
    var lastRequest: SyncBatchRequest?

    func syncBatch(_ request: SyncBatchRequest, token: String) async throws -> SyncBatchResponse {
        lastRequest = request
        return SyncBatchResponse(kits: [], steps: [], progressEntries: nil, sessions: nil, conflicts: [])
    }
}

@MainActor
private final class ContentEditingKeychainStore: KeychainStoring {
    private var values: [String: Data] = [:]

    func save<T: Codable>(_ value: T, forKey key: String) throws {
        values[key] = try JSONEncoder().encode(value)
    }

    func get<T: Codable>(forKey key: String) throws -> T? {
        guard let data = values[key] else { return nil }
        return try JSONDecoder().decode(T.self, from: data)
    }

    func saveString(_ value: String, forKey key: String) throws {
        values[key] = Data(value.utf8)
    }

    func getString(forKey key: String) throws -> String? {
        guard let data = values[key] else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func delete(forKey key: String) throws {
        values.removeValue(forKey: key)
    }
}
