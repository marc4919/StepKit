import Foundation
import SwiftData
import Testing
@testable import StepKit

@Suite("Client tombstone application", .serialized)
@MainActor
struct SyncTombstoneTests {
    @Test("Kit and Step tombstones are idempotent across repeated snapshots")
    func repeatedTombstonesRemainIdempotent() async throws {
        let initialDate = Date(timeIntervalSince1970: 1_700_000_000)
        let tombstoneDate = initialDate.addingTimeInterval(60)
        let persistence = PersistenceController(inMemory: true)
        let context = persistence.container.mainContext

        let deletedKit = makeKit(title: "Delete Kit", updatedAt: initialDate)
        let cascadedStep = makeStep(title: "Cascade Step", updatedAt: initialDate)
        cascadedStep.goal = deletedKit

        let survivingKit = makeKit(title: "Keep Kit", updatedAt: initialDate)
        let directlyDeletedStep = makeStep(title: "Delete Step", updatedAt: initialDate)
        directlyDeletedStep.goal = survivingKit
        let survivingStep = makeStep(title: "Keep Step", updatedAt: initialDate)
        survivingStep.goal = survivingKit

        context.insert(deletedKit)
        context.insert(cascadedStep)
        context.insert(survivingKit)
        context.insert(directlyDeletedStep)
        context.insert(survivingStep)
        try context.save()

        let snapshot = SyncBatchResponse(
            kits: [kitTombstone(for: deletedKit, at: tombstoneDate)],
            steps: [stepTombstone(for: directlyDeletedStep, at: tombstoneDate)],
            progressEntries: nil,
            sessions: nil,
            conflicts: []
        )
        let network = RepeatingTombstoneNetworkService(response: snapshot)
        let authManager = makeAuthenticatedManager()
        let preferencesName = "StepKitTests.Tombstones.\(UUID().uuidString)"
        let preferences = try #require(UserDefaults(suiteName: preferencesName))
        defer { preferences.removePersistentDomain(forName: preferencesName) }
        let cutoffs = TombstoneDateSequence([
            tombstoneDate.addingTimeInterval(60),
            tombstoneDate.addingTimeInterval(120),
        ])
        let service = SyncService(
            authManager: authManager,
            networkService: network,
            preferences: preferences,
            now: { cutoffs.next() }
        )
        service.configure(with: context)

        try await service.syncAll()
        try assertConvergedState(
            context: context,
            deletedKitID: deletedKit.id,
            cascadedStepID: cascadedStep.id,
            survivingKitID: survivingKit.id,
            directlyDeletedStepID: directlyDeletedStep.id,
            survivingStepID: survivingStep.id
        )

        try await service.syncAll()
        try assertConvergedState(
            context: context,
            deletedKitID: deletedKit.id,
            cascadedStepID: cascadedStep.id,
            survivingKitID: survivingKit.id,
            directlyDeletedStepID: directlyDeletedStep.id,
            survivingStepID: survivingStep.id
        )
        #expect(network.requestCount == 2)
    }

    private func assertConvergedState(
        context: ModelContext,
        deletedKitID: UUID,
        cascadedStepID: UUID,
        survivingKitID: UUID,
        directlyDeletedStepID: UUID,
        survivingStepID: UUID
    ) throws {
        let kits = try context.fetch(FetchDescriptor<GoalEntity>())
        let steps = try context.fetch(FetchDescriptor<StepEntity>())

        #expect(!kits.contains { $0.id == deletedKitID })
        #expect(kits.contains { $0.id == survivingKitID })
        #expect(!steps.contains { $0.id == cascadedStepID })
        #expect(!steps.contains { $0.id == directlyDeletedStepID })
        #expect(steps.contains { $0.id == survivingStepID })
    }

    private func makeKit(title: String, updatedAt: Date) -> GoalEntity {
        GoalEntity(
            ownerID: "account-a",
            planTitle: title,
            horizonDays: 30,
            kpi: "KPI",
            updatedAt: updatedAt
        )
    }

    private func makeStep(title: String, updatedAt: Date) -> StepEntity {
        StepEntity(
            ownerID: "account-a",
            stepTitle: title,
            descriptionShort: "Short",
            descriptionLong: "Long",
            estimateMinutes: 20,
            updatedAt: updatedAt
        )
    }

    private func kitTombstone(for kit: GoalEntity, at date: Date) -> KitSyncDTO {
        KitSyncDTO(
            id: kit.id,
            title: kit.planTitle,
            kpi: kit.kpi,
            horizonDays: kit.horizonDays,
            metaType: kit.metaType,
            metaTags: kit.metaTags,
            risks: kit.risks,
            version: kit.version + 1,
            progress: kit.progress,
            sourceModel: kit.sourceModel,
            promptVersion: nil,
            createdAt: kit.createdAt,
            updatedAt: date,
            deletedAt: date,
            deleted: true,
            resultConfirmedAt: nil,
            steps: nil
        )
    }

    private func stepTombstone(for step: StepEntity, at date: Date) -> StepSyncDTO {
        StepSyncDTO(
            id: step.id,
            kitId: step.goal?.id ?? UUID(),
            title: step.stepTitle,
            descriptionShort: step.descriptionShort,
            descriptionLong: step.descriptionLong,
            estimateMinutes: step.estimateMinutes,
            suggestedDeadline: step.suggestedDeadline,
            effortLevel: step.effortLevel,
            adaptsTo: step.adaptsTo,
            blockedByPremium: step.blockedByPremium,
            order: step.order,
            completed: step.isCompleted,
            blockedReason: nil,
            blockedAt: nil,
            createdAt: step.createdAt,
            updatedAt: date,
            deletedAt: date
        )
    }

    private func makeAuthenticatedManager() -> AuthManager {
        let manager = AuthManager(keychain: TombstoneKeychainStore())
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
private final class RepeatingTombstoneNetworkService: SyncNetworkServicing {
    private let response: SyncBatchResponse
    private(set) var requestCount = 0

    init(response: SyncBatchResponse) {
        self.response = response
    }

    func syncBatch(_ request: SyncBatchRequest, token: String) async throws -> SyncBatchResponse {
        requestCount += 1
        return response
    }
}

@MainActor
private final class TombstoneDateSequence {
    private var dates: [Date]

    init(_ dates: [Date]) {
        self.dates = dates
    }

    func next() -> Date {
        precondition(!dates.isEmpty)
        return dates.removeFirst()
    }
}

@MainActor
private final class TombstoneKeychainStore: KeychainStoring {
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
