import Foundation
import SwiftData
import Testing
@testable import StepKit

@Suite("Legacy ownership recovery", .serialized)
@MainActor
struct LegacyOwnershipRecoveryTests {
    @Test("Unowned data is claimed once and repeated recovery is idempotent")
    func claimsUnownedDataOnce() throws {
        let persistence = PersistenceController(inMemory: true)
        let context = persistence.container.mainContext
        let legacy = makeGoal(ownerID: "", title: "Legacy")
        let other = makeGoal(ownerID: "account-b", title: "Other")
        context.insert(legacy)
        context.insert(other)
        try context.save()

        let keychain = LegacyTestKeychainStore()
        let recovery = LegacyOwnershipRecovery(keychain: keychain, legacyData: persistence)

        #expect(try recovery.prepareClaimIfNeeded(previousOwnerID: "account-a") == .prepared)
        #expect(try recovery.claimIfAuthorized(authenticatedOwnerID: "account-a") == .claimed)
        #expect(legacy.ownerID == "account-a")
        #expect(other.ownerID == "account-b")
        #expect(try keychain.getString(forKey: LegacyOwnershipRecovery.pendingOwnerKey) == nil)

        #expect(try recovery.prepareClaimIfNeeded(previousOwnerID: "account-b") == .noLegacyData)
        #expect(try recovery.claimIfAuthorized(authenticatedOwnerID: "account-a") == .noPendingClaim)
        #expect(legacy.ownerID == "account-a")
    }

    @Test("A different owner cannot see, claim, or replace the anchored data")
    func rejectsDifferentOwner() throws {
        let persistence = PersistenceController(inMemory: true)
        let context = persistence.container.mainContext
        let legacy = makeGoal(ownerID: "", title: "Legacy")
        context.insert(legacy)
        try context.save()

        let keychain = LegacyTestKeychainStore()
        let recovery = LegacyOwnershipRecovery(keychain: keychain, legacyData: persistence)

        #expect(try recovery.prepareClaimIfNeeded(previousOwnerID: "account-a") == .prepared)
        #expect(try recovery.prepareClaimIfNeeded(previousOwnerID: "account-b") == .anchoredToDifferentOwner)
        #expect(try recovery.claimIfAuthorized(authenticatedOwnerID: "account-b") == .differentOwner)
        #expect(legacy.ownerID.isEmpty)
        #expect(try keychain.getString(forKey: LegacyOwnershipRecovery.pendingOwnerKey) == "account-a")

        let ownerB = "account-b"
        let visibleToB = try context.fetch(
            FetchDescriptor<GoalEntity>(predicate: #Predicate { $0.ownerID == ownerB })
        )
        #expect(visibleToB.isEmpty)

        #expect(try recovery.claimIfAuthorized(authenticatedOwnerID: "account-a") == .claimed)
        #expect(legacy.ownerID == "account-a")
    }

    @Test("Missing or malformed anchors fail closed")
    func malformedAnchorFailsClosed() throws {
        let persistence = PersistenceController(inMemory: true)
        let context = persistence.container.mainContext
        let legacy = makeGoal(ownerID: "", title: "Legacy")
        context.insert(legacy)
        try context.save()

        let keychain = LegacyTestKeychainStore()
        let recovery = LegacyOwnershipRecovery(keychain: keychain, legacyData: persistence)

        #expect(try recovery.claimIfAuthorized(authenticatedOwnerID: "account-a") == .noPendingClaim)
        try keychain.saveString("  ", forKey: LegacyOwnershipRecovery.pendingOwnerKey)
        #expect(try recovery.claimIfAuthorized(authenticatedOwnerID: "account-a") == .invalidStoredAnchor)
        #expect(try recovery.prepareClaimIfNeeded(previousOwnerID: "account-a") == .invalidStoredAnchor)
        #expect(legacy.ownerID.isEmpty)
        #expect(try keychain.getString(forKey: LegacyOwnershipRecovery.pendingOwnerKey) == "  ")
    }

    @Test("The anchor remains until a failed claim completes on retry")
    func failedClaimIsRecoverable() throws {
        let keychain = LegacyTestKeychainStore()
        let legacyData = FailOnceLegacyDataStore()
        let recovery = LegacyOwnershipRecovery(keychain: keychain, legacyData: legacyData)

        #expect(try recovery.prepareClaimIfNeeded(previousOwnerID: "account-a") == .prepared)
        do {
            _ = try recovery.claimIfAuthorized(authenticatedOwnerID: "account-a")
            Issue.record("Expected the first legacy claim to fail")
        } catch LegacyRecoveryTestError.claimFailed {
            // Expected: the marker must remain for the retry below.
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        #expect(try keychain.getString(forKey: LegacyOwnershipRecovery.pendingOwnerKey) == "account-a")
        #expect(legacyData.ownerID == nil)

        #expect(try recovery.claimIfAuthorized(authenticatedOwnerID: "account-a") == .claimed)
        #expect(legacyData.ownerID == "account-a")
        #expect(try keychain.getString(forKey: LegacyOwnershipRecovery.pendingOwnerKey) == nil)
    }

    @Test("Expired sessions preserve the previous owner; logout does not")
    func expiredSessionVersusVoluntaryLogout() async throws {
        let persistence = PersistenceController(inMemory: true)
        let keychain = LegacyTestKeychainStore()
        let recovery = LegacyOwnershipRecovery(keychain: keychain, legacyData: persistence)
        let initialManager = AuthManager(keychain: keychain, legacyRecovery: recovery)
        initialManager.saveAuth(token: "expired-token", user: makeUser(id: "account-a"))

        let legacy = makeGoal(ownerID: "", title: "Legacy")
        persistence.container.mainContext.insert(legacy)
        try persistence.container.mainContext.save()

        let restoredManager = AuthManager(keychain: keychain, legacyRecovery: recovery)
        let apiClient = MockAPIClient()
        apiClient.simulatedDelay = 0
        apiClient.shouldFailUserProfile = true

        #expect(await restoredManager.validateStoredSession(using: apiClient) == nil)
        #expect(try keychain.getString(forKey: LegacyOwnershipRecovery.pendingOwnerKey) == "account-a")
        #expect(legacy.ownerID.isEmpty)

        restoredManager.saveAuth(token: "token-b", user: makeUser(id: "account-b"))
        #expect(legacy.ownerID.isEmpty)
        #expect(try keychain.getString(forKey: LegacyOwnershipRecovery.pendingOwnerKey) == "account-a")

        restoredManager.saveAuth(token: "token-a", user: makeUser(id: "account-a"))
        #expect(legacy.ownerID == "account-a")
        #expect(try keychain.getString(forKey: LegacyOwnershipRecovery.pendingOwnerKey) == nil)

        let secondLegacy = makeGoal(ownerID: "", title: "Second legacy")
        persistence.container.mainContext.insert(secondLegacy)
        try persistence.container.mainContext.save()
        restoredManager.signOut()
        #expect(try keychain.getString(forKey: LegacyOwnershipRecovery.pendingOwnerKey) == nil)
        #expect(secondLegacy.ownerID.isEmpty)
    }

    private func makeUser(id: String) -> UserInfo {
        UserInfo(
            id: id,
            tier: "free",
            monthlyTokensUsed: 0,
            monthlyTokenQuota: 1_000
        )
    }

    private func makeGoal(ownerID: String, title: String) -> GoalEntity {
        GoalEntity(
            ownerID: ownerID,
            planTitle: title,
            horizonDays: 30,
            kpi: "Complete"
        )
    }
}

@MainActor
final class LegacyTestKeychainStore: KeychainStoring {
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

private enum LegacyRecoveryTestError: Error {
    case claimFailed
}

@MainActor
private final class FailOnceLegacyDataStore: LegacyDataClaiming {
    var ownerID: String?
    private var shouldFail = true

    func hasUnownedLegacyData() throws -> Bool {
        ownerID == nil
    }

    func claimLegacyData(for ownerID: String) throws {
        if shouldFail {
            shouldFail = false
            throw LegacyRecoveryTestError.claimFailed
        }
        self.ownerID = ownerID
    }
}
