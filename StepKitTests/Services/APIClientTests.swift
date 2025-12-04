//
//  APIClientTests.swift
//  StepKitTests
//
//  Created by Marc Garcia Teodoro on [Date]
//

import Testing
@testable import StepKit

@Suite("MockAPIClient Tests")
struct MockAPIClientTests {
    
    @Test("Should return success response by default")
    func defaultSuccessResponse() async throws {
        let mockClient = MockAPIClient()
        mockClient.simulatedDelay = 0.01 // Fast for tests
        
        let response = try await mockClient.signInWithApple(identityToken: "test-token")
        
        #expect(response.token.starts(with: "mock-jwt-token"))
        #expect(response.user.tier == "premium")
        #expect(response.user.monthlyTokenQuota == 10000)
    }
    
    @Test("Should fail when shouldFailLogin is true")
    func failsWhenConfigured() async throws {
        let mockClient = MockAPIClient()
        mockClient.shouldFailLogin = true
        mockClient.simulatedDelay = 0.01
        
        await #expect(throws: APIError.self) {
            try await mockClient.signInWithApple(identityToken: "test-token")
        }
    }
    
    @Test("Should use custom error when provided")
    func usesCustomError() async throws {
        let mockClient = MockAPIClient()
        mockClient.loginError = APIError.networkError(NSError(domain: "test", code: -1))
        mockClient.simulatedDelay = 0.01
        
        await #expect(throws: APIError.self) {
            try await mockClient.signInWithApple(identityToken: "test-token")
        }
    }
    
    @Test("Should use custom response when provided")
    func usesCustomResponse() async throws {
        let customResponse = AuthResponse(
            token: "custom-token",
            user: UserInfo(
                id: "custom-id",
                tier: "free",
                monthlyTokensUsed: 500,
                monthlyTokenQuota: 1000
            )
        )
        
        let mockClient = MockAPIClient()
        mockClient.mockAuthResponse = customResponse
        mockClient.simulatedDelay = 0.01
        
        let response = try await mockClient.signInWithApple(identityToken: "test-token")
        
        #expect(response.token == "custom-token")
        #expect(response.user.id == "custom-id")
        #expect(response.user.tier == "free")
    }
    
    @Test("Should create authenticated request")
    func createsAuthenticatedRequest() {
        let mockClient = MockAPIClient()
        let request = mockClient.authenticatedRequest(
            path: "/sync/batch",
            method: "POST",
            token: "test-token"
        )
        
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
    }
}

