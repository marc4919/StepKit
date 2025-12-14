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
    private let baseURL: String
    
    init(client: HTTPClient, baseURL: String) {
        self.client = client
        self.baseURL = baseURL
    }
    
    /// Autentica con Apple Sign In
    /// - Parameter identityToken: Token de identidad de Apple
    /// - Returns: Respuesta con token JWT y usuario
    func signInWithApple(identityToken: String) async throws -> AuthResponse {
        guard let url = URL(string: "\(baseURL)/auth/apple") else {
            throw APIError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["identityToken": identityToken]
        request.httpBody = try JSONEncoder().encode(body)
        
        return try await client.request(request)
    }
}
