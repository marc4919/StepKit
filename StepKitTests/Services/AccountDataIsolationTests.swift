import Foundation
import SwiftData
import Testing
@testable import StepKit

@Suite("Account data isolation", .serialized)
@MainActor
struct AccountDataIsolationTests {
    @Test("Legacy records are claimed only after a validated restore")
    func claimsOnlyLegacyRecords() throws {
        let persistence = PersistenceController(inMemory: true)
        let context = persistence.container.mainContext
        let legacy = makeGoal(ownerID: "", title: "Legacy")
        let other = makeGoal(ownerID: "account-b", title: "Other")
        context.insert(legacy)
        context.insert(other)
        try context.save()

        try persistence.claimLegacyData(for: "account-a")

        #expect(legacy.ownerID == "account-a")
        #expect(other.ownerID == "account-b")
    }

    @Test("Sync cursors are scoped by account")
    func syncCursorsAreScopedByAccount() {
        let suiteName = "StepKitTests.AccountCursor.\(UUID().uuidString)"
        let preferences = UserDefaults(suiteName: suiteName)!
        defer { preferences.removePersistentDomain(forName: suiteName) }

        let managerA = makeAuthenticatedManager(userID: "account-a")
        let serviceA = SyncService(authManager: managerA, preferences: preferences)
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        serviceA.lastSyncDate = date

        let managerB = makeAuthenticatedManager(userID: "account-b")
        let serviceB = SyncService(authManager: managerB, preferences: preferences)

        #expect(serviceA.lastSyncDate == date)
        #expect(serviceB.lastSyncDate == nil)
    }

    @Test("Sync sends only the authenticated account records")
    func syncSendsOnlyCurrentAccountRecords() async throws {
        let persistence = PersistenceController(inMemory: true)
        let context = persistence.container.mainContext
        let goalA = makeGoal(ownerID: "account-a", title: "A")
        let goalB = makeGoal(ownerID: "account-b", title: "B")
        context.insert(goalA)
        context.insert(goalB)
        try context.save()

        let network = CapturingSyncNetworkService()
        let manager = makeAuthenticatedManager(userID: "account-a")
        let service = SyncService(authManager: manager, networkService: network)
        service.configure(with: context)

        try await service.syncAll()

        #expect(network.lastRequest?.kits.map(\.title) == ["A"])
    }

    private func makeAuthenticatedManager(userID: String) -> AuthManager {
        let manager = AuthManager(keychain: IsolationTestKeychainStore())
        manager.saveAuth(
            token: "token-\(userID)",
            user: UserInfo(
                id: userID,
                tier: "premium",
                monthlyTokensUsed: 0,
                monthlyTokenQuota: 10_000
            )
        )
        return manager
    }

    private func makeGoal(ownerID: String, title: String) -> GoalEntity {
        GoalEntity(
            ownerID: ownerID,
            planTitle: title,
            horizonDays: 30,
            kpi: "Complete",
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }
}

@MainActor
private final class CapturingSyncNetworkService: SyncNetworkServicing {
    var lastRequest: SyncBatchRequest?

    func syncBatch(_ request: SyncBatchRequest, token: String) async throws -> SyncBatchResponse {
        lastRequest = request
        return SyncBatchResponse(kits: [], steps: [], conflicts: [])
    }
}

@MainActor
private final class IsolationTestKeychainStore: KeychainStoring {
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
