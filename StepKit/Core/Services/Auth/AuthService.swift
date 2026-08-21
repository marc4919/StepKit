//
//  AuthService.swift
//  StepKit
//
//  Created by StepKit Refactoring Agent
//

import Foundation

protocol AuthServiceProtocol {
    func signInWithApple(identityToken: String) async throws -> AuthResponse
}

/// Servicio encargado de la autenticación
struct AuthService: AuthServiceProtocol {
    private let client: HTTPClient
    private let baseURL: URL
    
    init(client: HTTPClient, baseURL: URL) {
        self.client = client
        self.baseURL = baseURL
    }
    
    /// Autentica con Apple Sign In
    /// - Parameter identityToken: Token de identidad de Apple
    /// - Returns: Respuesta con token JWT y usuario
    func signInWithApple(identityToken: String) async throws -> AuthResponse {
        let url = baseURL.appending(path: "auth/apple")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["identityToken": identityToken]
        request.httpBody = try JSONEncoder().encode(body)
        
        return try await client.request(request)
    }

    #if DEBUG
    /// Autenticación determinista para pruebas E2E locales. El tipo y la ruta no
    /// existen en compilaciones Release.
    func signInForE2E(account: E2EAccountAlias) async throws -> AuthResponse {
        try await client.request(Self.makeE2ERequest(baseURL: baseURL, account: account))
    }

    static func makeE2ERequest(baseURL: URL, account: E2EAccountAlias) throws -> URLRequest {
        let url = baseURL.appending(path: "auth/e2e")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(E2ELoginRequest(alias: account))
        return request
    }

    private struct E2ELoginRequest: Encodable {
        let alias: E2EAccountAlias
    }
    #endif
}
