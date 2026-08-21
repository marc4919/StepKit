#if DEBUG
import Foundation
import SwiftData
import Testing
@testable import StepKit

@Suite("Debug E2E authentication", .serialized)
@MainActor
struct E2EAuthenticationTests {
    @Test("Launch configuration requires one explicit fixed account")
    func launchConfigurationIsExplicit() {
        #expect(E2ELaunchConfiguration(arguments: ["StepKit"]) == nil)
        #expect(E2ELaunchConfiguration(arguments: [
            "StepKit",
            E2ELaunchConfiguration.resetLocalStateArgument,
        ]) == nil)
        #expect(E2ELaunchConfiguration(arguments: [
            "StepKit",
            E2ELaunchConfiguration.accountArgument,
            "arbitrary-user",
        ]) == nil)
        #expect(E2ELaunchConfiguration(arguments: [
            "StepKit",
            E2ELaunchConfiguration.accountArgument,
            E2EAccountAlias.accountA.rawValue,
            E2ELaunchConfiguration.accountArgument,
            E2EAccountAlias.accountB.rawValue,
        ]) == nil)
        #expect(E2ELaunchConfiguration.authenticationMode(arguments: [
            "StepKit",
            E2ELaunchConfiguration.resetLocalStateArgument,
        ]) == .invalid)
        #expect(E2ELaunchConfiguration.authenticationMode(arguments: [
            "StepKit",
            E2ELaunchConfiguration.accountArgument,
        ]) == .invalid)
        #expect(E2ELaunchConfiguration.authenticationMode(arguments: [
            "StepKit",
            E2ELaunchConfiguration.accountArgument,
            E2EAccountAlias.accountA.rawValue,
            E2ELaunchConfiguration.invalidStoredSessionArgument,
        ]) == .invalid)

        let configuration = E2ELaunchConfiguration(arguments: [
            "StepKit",
            E2ELaunchConfiguration.accountArgument,
            E2EAccountAlias.accountB.rawValue,
            E2ELaunchConfiguration.resetLocalStateArgument,
        ])
        #expect(configuration?.account == .accountB)
        #expect(configuration?.shouldResetLocalState == true)

        #expect(E2ELaunchConfiguration.requestsInvalidStoredSession(arguments: [
            "StepKit",
            E2ELaunchConfiguration.invalidStoredSessionArgument,
        ]))
        #expect(!E2ELaunchConfiguration.requestsInvalidStoredSession(arguments: [
            "StepKit",
            E2ELaunchConfiguration.invalidStoredSessionArgument,
            E2ELaunchConfiguration.accountArgument,
            E2EAccountAlias.accountA.rawValue,
        ]))
        #expect(!E2ELaunchConfiguration.requestsInvalidStoredSession(arguments: [
            "StepKit",
            E2ELaunchConfiguration.invalidStoredSessionArgument,
            E2ELaunchConfiguration.invalidStoredSessionArgument,
        ]))
    }

    @Test("Notification suppression covers account, invalid, and stored-session E2E launches")
    func notificationSuppressionIsExplicitAndDeterministic() {
        #expect(!E2ELaunchConfiguration.shouldSuppressNotifications(arguments: ["StepKit"]))
        #expect(E2ELaunchConfiguration.shouldSuppressNotifications(arguments: [
            "StepKit",
            E2ELaunchConfiguration.accountArgument,
            E2EAccountAlias.accountA.rawValue,
        ]))
        #expect(E2ELaunchConfiguration.shouldSuppressNotifications(arguments: [
            "StepKit",
            E2ELaunchConfiguration.invalidStoredSessionArgument,
        ]))
        #expect(E2ELaunchConfiguration.shouldSuppressNotifications(arguments: [
            "StepKit",
            E2ELaunchConfiguration.suppressNotificationsArgument,
        ]))
        #expect(!E2ELaunchConfiguration.shouldSuppressNotifications(arguments: [
            "StepKit",
            E2ELaunchConfiguration.suppressNotificationsArgument,
            E2ELaunchConfiguration.suppressNotificationsArgument,
        ]))
        #expect(!E2ELaunchConfiguration.shouldSuppressNotifications(arguments: [
            "StepKit",
            E2ELaunchConfiguration.accountArgument,
            E2EAccountAlias.accountA.rawValue,
            E2ELaunchConfiguration.invalidStoredSessionArgument,
            E2ELaunchConfiguration.suppressNotificationsArgument,
        ]))
    }

    @Test("Seeded invalid credentials use normal restore and fail closed")
    func invalidStoredSessionFailsClosed() async throws {
        let persistence = PersistenceController(inMemory: true)
        let keychain = LegacyTestKeychainStore()
        let recovery = LegacyOwnershipRecovery(
            keychain: keychain,
            legacyData: persistence
        )
        let authManager = AuthManager(
            keychain: keychain,
            legacyRecovery: recovery
        )
        try authManager.seedInvalidStoredSessionForE2E()

        #expect(authManager.isRestoringSession)
        #expect(authManager.currentUser?.id == "invalid-stored-session-owner")

        let apiClient = MockAPIClient()
        apiClient.simulatedDelay = 0
        apiClient.shouldFailUserProfile = true
        #expect(await authManager.validateStoredSession(using: apiClient) == nil)
        #expect(authManager.isAuthenticated == false)
        #expect(authManager.isRestoringSession == false)
        #expect(authManager.currentUser == nil)
        #expect(authManager.token == nil)
    }

    @Test("E2E request uses the normal API origin and fixed route contract")
    func requestContract() throws {
        let baseURL = try #require(URL(string: "http://localhost:8080"))
        let request = try AuthService.makeE2ERequest(
            baseURL: baseURL,
            account: .accountA
        )

        #expect(request.url?.absoluteString == "http://localhost:8080/auth/e2e")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")

        let body = try #require(request.httpBody)
        let object = try #require(
            JSONSerialization.jsonObject(with: body) as? [String: String]
        )
        #expect(object == ["alias": E2EAccountAlias.accountA.rawValue])
    }

    @Test("Local reset is limited to StepKit-owned sandbox state")
    func localResetClearsOwnedState() throws {
        let suiteName = "StepKitTests.E2EReset.\(UUID().uuidString)"
        let preferences = try #require(UserDefaults(suiteName: suiteName))
        defer { preferences.removePersistentDomain(forName: suiteName) }

        let persistence = PersistenceController(inMemory: true)
        let keychain = LegacyTestKeychainStore()
        let recovery = LegacyOwnershipRecovery(
            keychain: keychain,
            legacyData: persistence
        )
        let authManager = AuthManager(
            keychain: keychain,
            legacyRecovery: recovery
        )
        authManager.saveAuth(token: "local-token", user: makeUser(id: "account-a"))

        let context = persistence.container.mainContext
        context.insert(makeLegacyGoal())
        try context.save()
        _ = try recovery.prepareClaimIfNeeded(previousOwnerID: "account-a")
        preferences.set(true, forKey: "hasCompletedOnboarding")

        try E2ELocalStateResetter(
            persistence: persistence,
            preferences: preferences,
            preferencesDomain: suiteName
        ).reset(authentication: authManager)

        #expect(try context.fetch(FetchDescriptor<GoalEntity>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<StepEntity>()).isEmpty)
        #expect(authManager.token == nil)
        #expect(authManager.currentUser == nil)
        #expect(authManager.isAuthenticated == false)
        #expect(try keychain.getString(forKey: LegacyOwnershipRecovery.pendingOwnerKey) == nil)
        #expect(preferences.object(forKey: "hasCompletedOnboarding") == nil)
    }

    private func makeUser(id: String) -> UserInfo {
        UserInfo(
            id: id,
            tier: "free",
            monthlyTokensUsed: 0,
            monthlyTokenQuota: 1_000
        )
    }

    private func makeLegacyGoal() -> GoalEntity {
        GoalEntity(
            ownerID: "",
            planTitle: "Legacy",
            horizonDays: 30,
            kpi: "Complete"
        )
    }
}
#endif
