//
//  AuthManagerTests.swift
//  StepKitTests
//
//  Created by Marc Garcia Teodoro on [Date]
//

import Testing
@testable import StepKit

@Suite("AuthManager Tests")
struct AuthManagerTests {
    
    @Test("Should start unauthenticated")
    func startsUnauthenticated() {
        let keychain = KeychainManager.shared
        let authManager = AuthManager(keychain: keychain)
        
        #expect(authManager.isAuthenticated == false)
        #expect(authManager.currentUser == nil)
        #expect(authManager.token == nil)
    }
    
    @Test("Should save auth and become authenticated")
    func savesAuth() {
        let keychain = KeychainManager.shared
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
    
    @Test("Should sign out and clear auth")
    func signsOut() {
        let keychain = KeychainManager.shared
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
}

@Suite("MockAuthManager Tests")
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



