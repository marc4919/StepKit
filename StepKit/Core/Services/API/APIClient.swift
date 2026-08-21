//
//  APIClient.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on [Date]
//

import Foundation

/// Cliente HTTP real para comunicarse con el backend
final class APIClient: APIClientProtocol {
    /// URL base del servidor
    private let baseURL: URL
    
    private let httpClient: HTTPClient
    private let authService: AuthService

    /// Inicializa el cliente desde la única configuración validada de la app.
    init(environment: AppEnvironment? = nil) {
        let environment = environment ?? .current
        self.baseURL = environment.apiBaseURL
        self.httpClient = HTTPClient()
        self.authService = AuthService(client: httpClient, baseURL: environment.apiBaseURL)
    }
    
    // MARK: - APIClientProtocol
    
    func signInWithApple(identityToken: String) async throws -> AuthResponse {
        return try await authService.signInWithApple(identityToken: identityToken)
    }

    #if DEBUG
    func signInForE2E(account: E2EAccountAlias) async throws -> AuthResponse {
        try await authService.signInForE2E(account: account)
    }
    #endif
    
    func generateKit(from request: AIGenerateKitRequest, token: String) async throws -> AIGenerateKitResponse {
        let url = baseURL.appending(path: "ai/chat-sync")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let encoder = JSONEncoder()
        // Vapor usa camelCase, no convertir a snake_case
        urlRequest.httpBody = try encoder.encode(request)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        #if DEBUG
        NetworkDiagnostics.logResponse(
            operation: "Kit generation",
            statusCode: httpResponse.statusCode,
            byteCount: data.count
        )
        #endif
        
        switch httpResponse.statusCode {
        case 200...299:
            let decoder = JSONDecoder.flexibleDateDecoder

            do {
                let response = try decoder.decode(AIGenerateKitResponse.self, from: data)
                #if DEBUG
                print("✅ Kit decoded: steps=\(response.kit?.steps?.count ?? 0)")
                #endif
                return response
            } catch {
                #if DEBUG
                NetworkDiagnostics.logDecodingError(error, operation: "Kit generation")
                #endif
                throw APIError.decodingError(error)
            }
        case 401:
            throw APIError.notAuthenticated
        case 402:
            throw APIError.premiumRequired
        case 429:
            throw APIError.quotaExceeded
        default:
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.serverError(httpResponse.statusCode, errorMessage)
        }
    }
    
    func authenticatedRequest(path: String, method: String = "GET", token: String) -> URLRequest {
        let url = baseURL.appending(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        return request
    }

    // MARK: - Sync Batch

    /// Sincroniza datos locales con el servidor usando LWW (Last-Write-Wins)
    /// - Parameters:
    ///   - request: Kits y Steps locales a sincronizar
    ///   - token: JWT token de autenticación
    /// - Returns: Estado actual del servidor + conflictos detectados
    func syncBatch(_ request: SyncBatchRequest, token: String) async throws -> SyncBatchResponse {
        let url = baseURL.appending(path: "sync/batch")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        urlRequest.httpBody = try encoder.encode(request)

        #if DEBUG
        NetworkDiagnostics.logRequest(
            operation: "Sync",
            byteCount: urlRequest.httpBody?.count ?? 0,
            itemCount: request.kits.count + request.steps.count
        )
        #endif

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        #if DEBUG
        NetworkDiagnostics.logResponse(
            operation: "Sync",
            statusCode: httpResponse.statusCode,
            byteCount: data.count
        )
        #endif

        switch httpResponse.statusCode {
        case 200...299:
            return try JSONDecoder.flexibleDateDecoder.decode(SyncBatchResponse.self, from: data)

        case 401:
            throw APIError.notAuthenticated
        default:
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.serverError(httpResponse.statusCode, errorMessage)
        }
    }

    // MARK: - Subscription Verification

    /// Verifies a StoreKit 2 transaction with the backend
    /// - Parameters:
    ///   - transactionId: Original transaction ID from StoreKit
    ///   - token: JWT authentication token
    /// - Returns: Verification response with updated tier and subscription info
    func verifySubscription(transactionId: String, token: String) async throws -> VerifySubscriptionResponse {
        let url = baseURL.appending(path: "subscription/verify")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let body = ["transactionId": transactionId]
        urlRequest.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(VerifySubscriptionResponse.self, from: data)
        case 401:
            throw APIError.notAuthenticated
        default:
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.serverError(httpResponse.statusCode, errorMessage)
        }
    }
    
    // MARK: - User Profile
    
    func getUserProfile(token: String) async throws -> UserInfo {
        let url = baseURL.appending(path: "me")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let profile = try decoder.decode(UserProfileResponse.self, from: data)
            return UserInfo(from: profile)
        case 401:
            throw APIError.notAuthenticated
        default:
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.serverError(httpResponse.statusCode, errorMessage)
        }
    }

    // MARK: - Streaming Kit Generation

    func streamKitGeneration(from request: AIGenerateKitRequest, token: String) -> AsyncThrowingStream<AIChatStreamEvent, Error> {
        let baseURL = self.baseURL

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let url = baseURL.appending(path: "ai/chat")
                    var urlRequest = URLRequest(url: url)
                    urlRequest.httpMethod = "POST"
                    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    urlRequest.httpBody = try JSONEncoder().encode(request)

                    let (bytes, response) = try await URLSession.shared.bytes(for: urlRequest)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: APIError.invalidResponse)
                        return
                    }

                    // Check for error status codes
                    switch httpResponse.statusCode {
                    case 200...299:
                        break
                    case 401:
                        continuation.finish(throwing: APIError.notAuthenticated)
                        return
                    case 402:
                        continuation.finish(throwing: APIError.premiumRequired)
                        return
                    case 429:
                        continuation.finish(throwing: APIError.quotaExceeded)
                        return
                    default:
                        continuation.finish(throwing: APIError.serverError(httpResponse.statusCode, "Stream error"))
                        return
                    }

                    // Parse SSE events usando el parser
                    let eventStream = SSEParser.parse(bytes, as: AIChatStreamEvent.self)
                    for try await event in eventStream {
                        #if DEBUG
                        print("✅ SSE Event: type=\(event.type), step=\(event.step != nil ? "present" : "nil")")
                        #endif
                        continuation.yield(event)
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
