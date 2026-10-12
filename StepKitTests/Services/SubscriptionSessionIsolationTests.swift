import Foundation
import Testing
@testable import StepKit

@Suite("Subscription session isolation", .serialized)
@MainActor
struct SubscriptionSessionIsolationTests {
    enum Action: CaseIterable { case purchase, restore }
    enum Stage: CaseIterable { case store, verification, profile }
    enum Mutation: CaseIterable { case otherAccount, logout, sameCredentials, tokenReplacement }
    struct Interleaving {
        let stage: Stage
        let mutation: Mutation
        static var all: [Self] {
            Stage.allCases.flatMap { stage in Mutation.allCases.map { Self(stage: stage, mutation: $0) } }
        }
    }

    @Test("An obsolete response cannot change memory, Keychain or alerts", arguments: Action.allCases, Interleaving.all)
    func obsoleteResponse(action: Action, interleaving: Interleaving) async throws {
        let stage = interleaving.stage
        let mutation = interleaving.mutation
        let fixture = try Fixture(stage: stage)
        defer { fixture.cleanPreferences() }
        let task = Task { await fixture.run(action) }
        await fixture.gate.waitUntilEntered()
        fixture.mutate(mutation)
        let expectedUser = fixture.auth.currentUser
        let expectedToken = fixture.auth.token
        let persisted = fixture.keychain.values
        fixture.gate.resume()
        await task.value

        #expect(fixture.auth.currentUser?.id == expectedUser?.id)
        #expect(fixture.auth.currentUser?.tier == expectedUser?.tier)
        #expect(fixture.auth.token == expectedToken)
        #expect(fixture.keychain.values == persisted)
        #expect(!fixture.viewModel.showSuccessAlert)
        #expect(fixture.viewModel.errorMessage == nil)
        #expect(!fixture.viewModel.isLoading)
        if stage == .store { #expect(fixture.api.verificationTokens.isEmpty) }
        if stage != .profile { #expect(fixture.api.profileTokens.isEmpty) }
        #expect(fixture.api.verificationTokens.allSatisfy { $0 == "test-token-a" })
        #expect(fixture.api.profileTokens.allSatisfy { $0 == "test-token-a" })
    }

    @Test("Restore does not adopt a login changed while reading entitlements", arguments: Mutation.allCases)
    func obsoleteEntitlement(mutation: Mutation) async throws {
        let fixture = try Fixture(stage: nil)
        defer { fixture.cleanPreferences() }
        fixture.store.transactionGate = fixture.gate
        let task = Task { await fixture.run(.restore) }
        await fixture.gate.waitUntilEntered()
        fixture.mutate(mutation)
        let persisted = fixture.keychain.values
        fixture.gate.resume()
        await task.value
        #expect(fixture.api.verificationTokens.isEmpty)
        #expect(fixture.keychain.values == persisted)
        #expect(!fixture.viewModel.showSuccessAlert)
        #expect(fixture.viewModel.errorMessage == nil)
    }

    @Test("The current session receives its premium profile", arguments: Action.allCases)
    func currentResponse(action: Action) async throws {
        let fixture = try Fixture(stage: nil)
        defer { fixture.cleanPreferences() }
        let sessionID = fixture.auth.sessionID
        await fixture.run(action)
        let persisted: UserInfo? = try fixture.keychain.get(forKey: "stepkit_user_info")
        #expect(fixture.auth.currentUser?.uuid == fixture.userA.uuid)
        #expect(fixture.auth.currentUser?.isPremium == true)
        #expect(persisted?.uuid == fixture.userA.uuid)
        #expect(persisted?.isPremium == true)
        #expect(fixture.auth.token == "test-token-a")
        #expect(fixture.auth.sessionID == sessionID)
        #expect(fixture.store.purchaseOwner == (action == .purchase ? fixture.userA.uuid : nil))
        #expect(fixture.api.verificationTokens == ["test-token-a"])
        #expect(fixture.api.profileTokens == ["test-token-a"])
        #expect(fixture.viewModel.showSuccessAlert)
        #expect(fixture.viewModel.errorMessage == nil)
        #expect(!fixture.viewModel.isLoading)
    }

    @Test("A profile belonging to another identity is rejected", arguments: Action.allCases)
    func mismatchedProfile(action: Action) async throws {
        let fixture = try Fixture(stage: nil)
        defer { fixture.cleanPreferences() }
        fixture.api.profile = fixture.userB
        let persisted = fixture.keychain.values
        await fixture.run(action)
        #expect(fixture.auth.currentUser?.uuid == fixture.userA.uuid)
        #expect(fixture.auth.currentUser?.tier == "free")
        #expect(fixture.keychain.values == persisted)
        #expect(!fixture.viewModel.showSuccessAlert)
        #expect(fixture.viewModel.errorMessage != nil)
    }

    @Test("Errors arriving after logout cannot show stale alerts", arguments: Action.allCases, [Stage.verification, .profile])
    func obsoleteError(action: Action, stage: Stage) async throws {
        let fixture = try Fixture(stage: stage)
        defer { fixture.cleanPreferences() }
        fixture.api.failingStage = stage
        let task = Task { await fixture.run(action) }
        await fixture.gate.waitUntilEntered()
        fixture.auth.signOut()
        let persisted = fixture.keychain.values
        fixture.gate.resume()
        await task.value
        #expect(!fixture.auth.isAuthenticated)
        #expect(fixture.keychain.values == persisted)
        #expect(fixture.viewModel.errorMessage == nil)
        #expect(!fixture.viewModel.showSuccessAlert)
    }

    @Test("Cancellation discards responses even when the dependency ignores it", arguments: Action.allCases, Stage.allCases)
    func cancelledResponse(action: Action, stage: Stage) async throws {
        let fixture = try Fixture(stage: stage)
        defer { fixture.cleanPreferences() }
        let task = Task { await fixture.run(action) }
        await fixture.gate.waitUntilEntered()
        let persisted = fixture.keychain.values
        task.cancel()
        fixture.gate.resume()
        await task.value
        #expect(fixture.auth.currentUser?.tier == "free")
        #expect(fixture.keychain.values == persisted)
        #expect(fixture.viewModel.errorMessage == nil)
        #expect(!fixture.viewModel.showSuccessAlert)
        #expect(!fixture.viewModel.isLoading)
    }

    @Test("Unauthenticated actions do not reach StoreKit", arguments: Action.allCases)
    func unauthenticated(action: Action) async throws {
        let fixture = try Fixture(stage: nil)
        defer { fixture.cleanPreferences() }
        fixture.auth.signOut()
        await fixture.run(action)
        #expect(fixture.store.calls == 0)
        #expect(fixture.api.verificationTokens.isEmpty)
        #expect(fixture.viewModel.errorMessage != nil)
    }

    @Test("Session identity changes on login, replacement, restoration and logout")
    func sessionLifecycle() throws {
        let fixture = try Fixture(stage: nil)
        defer { fixture.cleanPreferences() }
        var previous = fixture.auth.sessionID
        fixture.auth.saveAuth(token: "test-token-a", user: fixture.userA)
        #expect(fixture.auth.sessionID != previous)
        previous = fixture.auth.sessionID
        fixture.auth.token = "test-token-a"
        #expect(fixture.auth.sessionID != previous)
        previous = fixture.auth.sessionID
        fixture.auth.completeStoredSessionRestore(with: fixture.userA)
        #expect(fixture.auth.sessionID != previous)
        previous = fixture.auth.sessionID
        fixture.auth.signOut()
        #expect(fixture.auth.sessionID != previous)
    }

    @MainActor
    private final class Fixture {
        let keychain = MemoryKeychain()
        let gate = Gate()
        let viewModel = SubscriptionViewModel()
        let userA = UserInfo(id: UUID().uuidString, tier: "free", monthlyTokensUsed: 0, monthlyTokenQuota: 1000)
        let userB = UserInfo(id: UUID().uuidString, tier: "free", monthlyTokensUsed: 0, monthlyTokenQuota: 1000)
        let auth: AuthManager
        let api: SubscriptionAPI
        let store = SubscriptionStore()
        let suite = "StepKitTests.Subscription.\(UUID().uuidString)"
        let preferences: UserDefaults

        init(stage: Stage?) throws {
            preferences = try #require(UserDefaults(suiteName: suite))
            auth = AuthManager(keychain: keychain, legacyRecovery: LegacyOwnershipRecovery(keychain: keychain, legacyData: EmptyLegacy()), preferences: preferences)
            auth.saveAuth(token: "test-token-a", user: userA)
            api = SubscriptionAPI(profile: UserInfo(id: userA.id, tier: "premium", monthlyTokensUsed: 0, monthlyTokenQuota: 10000))
            if stage == .store { store.gate = gate }
            else { api.stage = stage; api.gate = gate }
        }

        func cleanPreferences() { preferences.removePersistentDomain(forName: suite) }
        func run(_ action: Action) async {
            switch action {
            case .purchase: await viewModel.subscribeToPlan(storeKitManager: store, apiClient: api, authManager: auth)
            case .restore: await viewModel.restorePurchases(storeKitManager: store, apiClient: api, authManager: auth)
            }
        }
        func mutate(_ mutation: Mutation) {
            switch mutation {
            case .otherAccount:
                auth.signOut(); auth.saveAuth(token: "test-token-b", user: userB)
            case .logout: auth.signOut()
            case .sameCredentials:
                auth.signOut(); auth.saveAuth(token: "test-token-b", user: userB)
                auth.signOut(); auth.saveAuth(token: "test-token-a", user: userA)
            case .tokenReplacement: auth.token = "replacement-token-a"
            }
        }
    }

    /// A deterministic suspension; intentionally does not respond to cancellation.
    @MainActor
    private final class Gate {
        var continuation: CheckedContinuation<Void, Never>?
        var entryWaiter: CheckedContinuation<Void, Never>?
        var entered = false
        func pause() async {
            await withCheckedContinuation { continuation in
                self.continuation = continuation
                entered = true
                entryWaiter?.resume()
                entryWaiter = nil
            }
        }
        func waitUntilEntered() async {
            if entered { return }
            await withCheckedContinuation { entryWaiter = $0 }
        }
        func resume() { continuation?.resume(); continuation = nil }
    }

    @MainActor
    private final class SubscriptionStore: SubscriptionPurchasing {
        var hasActiveSubscription = true
        var gate: Gate?
        var transactionGate: Gate?
        var purchaseOwner: UUID?
        var calls = 0
        func isProductAvailable(for plan: SubscriptionPlan) -> Bool { true }
        func purchaseSubscription(plan: SubscriptionPlan, appAccountToken: UUID) async throws -> String {
            calls += 1; purchaseOwner = appAccountToken
            await gate?.pause()
            return "test-transaction"
        }
        func restorePurchases() async { calls += 1; await gate?.pause() }
        func getOriginalTransactionId() async -> String? { await transactionGate?.pause(); return "test-transaction" }
    }

    @MainActor
    private final class SubscriptionAPI: @MainActor APIClientProtocol {
        var profile: UserInfo
        var stage: Stage?
        var failingStage: Stage?
        var gate: Gate?
        var verificationTokens: [String] = []
        var profileTokens: [String] = []
        init(profile: UserInfo) { self.profile = profile }
        func verifySubscription(transactionId: String, token: String) async throws -> VerifySubscriptionResponse {
            verificationTokens.append(token)
            if stage == .verification { await gate?.pause() }
            if failingStage == .verification { throw APIError.invalidResponse }
            return VerifySubscriptionResponse(tier: "premium", expiresAt: nil, status: "active", productId: nil)
        }
        func getUserProfile(token: String) async throws -> UserInfo {
            profileTokens.append(token)
            if stage == .profile { await gate?.pause() }
            if failingStage == .profile { throw APIError.invalidResponse }
            return profile
        }
        func signInWithApple(identityToken: String) async throws -> AuthResponse { throw APIError.invalidResponse }
        func generateKit(from request: AIGenerateKitRequest, token: String) async throws -> AIGenerateKitResponse { throw APIError.invalidResponse }
        nonisolated func authenticatedRequest(path: String, method: String, token: String) -> URLRequest { URLRequest(url: URL(string: "http://localhost")!) }
        nonisolated func streamKitGeneration(from request: AIGenerateKitRequest, token: String) -> AsyncThrowingStream<AIChatStreamEvent, Error> { AsyncThrowingStream { $0.finish() } }
    }

    @MainActor
    private final class MemoryKeychain: KeychainStoring {
        var values: [String: Data] = [:]
        func save<T: Codable>(_ value: T, forKey key: String) throws { values[key] = try JSONEncoder().encode(value) }
        func get<T: Codable>(forKey key: String) throws -> T? {
            guard let data = values[key] else { return nil }
            return try JSONDecoder().decode(T.self, from: data)
        }
        func saveString(_ value: String, forKey key: String) throws { values[key] = Data(value.utf8) }
        func getString(forKey key: String) throws -> String? { values[key].flatMap { String(data: $0, encoding: .utf8) } }
        func delete(forKey key: String) throws { values.removeValue(forKey: key) }
    }

    @MainActor
    private final class EmptyLegacy: LegacyDataClaiming {
        func hasUnownedLegacyData() throws -> Bool { false }
        func claimLegacyData(for ownerID: String) throws {}
    }
}
