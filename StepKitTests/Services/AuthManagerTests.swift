//
//  AuthManagerTests.swift
//  StepKitTests
//
//  Created by Marc Garcia Teodoro on [Date]
//

import Testing
import Foundation
@testable import StepKit

@Suite("AuthManager Tests")
@MainActor
struct AuthManagerTests {
    
    @Test("Should start unauthenticated")
    func startsUnauthenticated() {
        let keychain = InMemoryKeychainStore()
        let authManager = AuthManager(keychain: keychain)
        
        #expect(authManager.isAuthenticated == false)
        #expect(authManager.currentUser == nil)
        #expect(authManager.token == nil)
    }
    
    @Test("Should save auth and become authenticated")
    func savesAuth() {
        let keychain = InMemoryKeychainStore()
        let authManager = AuthManager(keychain: keychain)
        
        let user = UserInfo(
            id: UUID().uuidString,
            tier: "premium",
            monthlyTokensUsed: 0,
            monthlyTokenQuota: 10000
        )
        
        authManager.saveAuth(token: "test-token", user: user)
        
        #expect(authManager.isAuthenticated == true)
        #expect(authManager.currentUser?.id == user.id)
        #expect(authManager.token == "test-token")
    }

    @Test("A user write failure never activates or commits a token")
    func userPersistenceFailureFailsClosed() {
        let keychain = FailingAuthKeychainStore(failure: .userWrite)
        let authManager = AuthManager(keychain: keychain)
        keychain.operations.removeAll()

        let user = UserInfo(
            id: "account-a",
            tier: "free",
            monthlyTokensUsed: 0,
            monthlyTokenQuota: 1_000
        )
        authManager.saveAuth(token: "uncommitted-token", user: user)

        #expect(keychain.operations.first == .saveValue("stepkit_user_info"))
        #expect(!keychain.operations.contains(.saveString("stepkit_jwt_token")))
        #expect(authManager.isAuthenticated == false)
        #expect(authManager.isRestoringSession == false)
        #expect(authManager.currentUser == nil)
        #expect(authManager.token == nil)
    }

    @Test("The token is the final commit marker and its failure is cleaned")
    func tokenPersistenceFailureFailsClosed() {
        let keychain = FailingAuthKeychainStore(failure: .tokenWrite)
        let authManager = AuthManager(keychain: keychain)
        keychain.operations.removeAll()

        let user = UserInfo(
            id: "account-a",
            tier: "free",
            monthlyTokensUsed: 0,
            monthlyTokenQuota: 1_000
        )
        authManager.saveAuth(token: "uncommitted-token", user: user)

        #expect(Array(keychain.operations.prefix(2)) == [
            .saveValue("stepkit_user_info"),
            .saveString("stepkit_jwt_token"),
        ])
        #expect(keychain.operations.contains(.delete("stepkit_user_info")))
        #expect(keychain.operations.contains(.delete("stepkit_jwt_token")))
        #expect(authManager.isAuthenticated == false)
        #expect(authManager.isRestoringSession == false)
        #expect(authManager.currentUser == nil)
        #expect(authManager.token == nil)
    }
    
    @Test("Should sign out and clear auth")
    func signsOut() {
        let keychain = InMemoryKeychainStore()
        let authManager = AuthManager(keychain: keychain)
        
        let user = UserInfo(
            id: UUID().uuidString,
            tier: "premium",
            monthlyTokensUsed: 0,
            monthlyTokenQuota: 10000
        )
        
        authManager.saveAuth(token: "test-token", user: user)
        authManager.signOut()
        
        #expect(authManager.isAuthenticated == false)
        #expect(authManager.currentUser == nil)
        #expect(authManager.token == nil)
    }

    @Test("Logout remains closed when Keychain cannot remove or blank the token")
    func logoutFailureCannotRestoreSurvivingToken() throws {
        let suiteName = "StepKitTests.AuthForcedSignOut.\(UUID().uuidString)"
        let preferences = try #require(UserDefaults(suiteName: suiteName))
        defer { preferences.removePersistentDomain(forName: suiteName) }

        let user = UserInfo(
            id: "account-a",
            tier: "free",
            monthlyTokensUsed: 0,
            monthlyTokenQuota: 1_000
        )
        let keychain = FailingAuthKeychainStore(failure: .logoutInvalidation)
        try keychain.seed(token: "surviving-token", user: user)

        let authManager = AuthManager(keychain: keychain, preferences: preferences)
        #expect(authManager.isRestoringSession)
        authManager.completeStoredSessionRestore(with: user)
        #expect(authManager.isAuthenticated)

        authManager.signOut()
        #expect(!authManager.isAuthenticated)
        #expect(authManager.token == nil)

        let relaunchedManager = AuthManager(keychain: keychain, preferences: preferences)
        #expect(!relaunchedManager.isAuthenticated)
        #expect(!relaunchedManager.isRestoringSession)
        #expect(relaunchedManager.currentUser == nil)
        #expect(relaunchedManager.token == nil)
    }

    @Test("Stored credentials require server validation")
    func storedCredentialsRequireValidation() async {
        let keychain = InMemoryKeychainStore()
        let originalUser = UserInfo(
            id: UUID().uuidString,
            tier: "free",
            monthlyTokensUsed: 0,
            monthlyTokenQuota: 1000
        )

        let initialManager = AuthManager(keychain: keychain)
        initialManager.saveAuth(token: "stored-token", user: originalUser)

        let restoredManager = AuthManager(keychain: keychain)
        #expect(restoredManager.isAuthenticated == false)
        #expect(restoredManager.isRestoringSession == true)

        let apiClient = MockAPIClient()
        apiClient.simulatedDelay = 0
        apiClient.mockUserProfile = originalUser

        let validatedUser = await restoredManager.validateStoredSession(using: apiClient)
        #expect(validatedUser?.id == originalUser.id)
        #expect(restoredManager.isAuthenticated == false)

        if let validatedUser {
            restoredManager.completeStoredSessionRestore(with: validatedUser)
        }
        #expect(restoredManager.isAuthenticated == true)
        #expect(restoredManager.isRestoringSession == false)
    }

    @Test("Rejected stored credentials fail closed")
    func rejectedStoredCredentialsFailClosed() async {
        let keychain = InMemoryKeychainStore()
        let user = UserInfo(
            id: UUID().uuidString,
            tier: "free",
            monthlyTokensUsed: 0,
            monthlyTokenQuota: 1000
        )

        let initialManager = AuthManager(keychain: keychain)
        initialManager.saveAuth(token: "expired-token", user: user)

        let restoredManager = AuthManager(keychain: keychain)
        let apiClient = MockAPIClient()
        apiClient.simulatedDelay = 0
        apiClient.shouldFailUserProfile = true

        let validatedUser = await restoredManager.validateStoredSession(using: apiClient)
        #expect(validatedUser == nil)
        #expect(restoredManager.isAuthenticated == false)
        #expect(restoredManager.isRestoringSession == false)
        #expect(restoredManager.token == nil)
    }
}

@Suite("MockAuthManager Tests")
@MainActor
struct MockAuthManagerTests {
    
    @Test("Should allow custom initial state")
    func customInitialState() {
        let user = UserInfo(
            id: "123",
            tier: "premium",
            monthlyTokensUsed: 0,
            monthlyTokenQuota: 10000
        )
        
        let mockAuth = MockAuthManager(
            isAuthenticated: true,
            user: user,
            token: "mock-token"
        )
        
        #expect(mockAuth.isAuthenticated == true)
        #expect(mockAuth.currentUser?.id == "123")
        #expect(mockAuth.token == "mock-token")
    }
    
    @Test("Should save auth correctly")
    func savesAuth() {
        let mockAuth = MockAuthManager()
        let user = UserInfo(
            id: UUID().uuidString,
            tier: "free",
            monthlyTokensUsed: 100,
            monthlyTokenQuota: 1000
        )
        
        mockAuth.saveAuth(token: "new-token", user: user)
        
        #expect(mockAuth.isAuthenticated == true)
        #expect(mockAuth.currentUser?.id == user.id)
        #expect(mockAuth.token == "new-token")
    }
}

@MainActor
private final class InMemoryKeychainStore: KeychainStoring {
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

@MainActor
private final class FailingAuthKeychainStore: KeychainStoring {
    enum Failure: Equatable {
        case userWrite
        case tokenWrite
        case logoutInvalidation
    }

    enum Operation: Equatable {
        case saveValue(String)
        case saveString(String)
        case delete(String)
    }

    let failure: Failure
    var operations: [Operation] = []
    private var values: [String: Data] = [:]

    init(failure: Failure) {
        self.failure = failure
    }

    func save<T: Codable>(_ value: T, forKey key: String) throws {
        operations.append(.saveValue(key))
        if failure == .userWrite {
            throw TestKeychainFailure.writeRejected
        }
        values[key] = try JSONEncoder().encode(value)
    }

    func get<T: Codable>(forKey key: String) throws -> T? {
        guard let data = values[key] else { return nil }
        return try JSONDecoder().decode(T.self, from: data)
    }

    func saveString(_ value: String, forKey key: String) throws {
        operations.append(.saveString(key))
        if failure == .tokenWrite
            || (failure == .logoutInvalidation && key == "stepkit_jwt_token") {
            throw TestKeychainFailure.writeRejected
        }
        values[key] = Data(value.utf8)
    }

    func getString(forKey key: String) throws -> String? {
        guard let data = values[key] else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func delete(forKey key: String) throws {
        operations.append(.delete(key))
        if failure == .logoutInvalidation && key == "stepkit_jwt_token" {
            throw TestKeychainFailure.writeRejected
        }
        values.removeValue(forKey: key)
    }

    func seed(token: String, user: UserInfo) throws {
        values["stepkit_jwt_token"] = Data(token.utf8)
        values["stepkit_user_info"] = try JSONEncoder().encode(user)
    }

    private enum TestKeychainFailure: Error {
        case writeRejected
    }
}
