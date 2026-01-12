//
//  APIClient.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on [Date]
//

import Foundation

/// Cliente HTTP real para comunicarse con el backend
final class APIClient: APIClientProtocol {
    /// URL base del servidor según el entorno
    #if DEBUG
    // TODO: Cambiar a localhost:8080 para desarrollo local
    private static let defaultBaseURL = "https://stepkitserver-production.up.railway.app"
    #else
    private static let defaultBaseURL = "https://stepkitserver-production.up.railway.app"
    #endif

    /// URL base del servidor
    private let baseURL: String
    
    private let httpClient: HTTPClient
    private let authService: AuthService

    /// Inicializa el cliente con una URL base
    /// - Parameter baseURL: URL base del servidor (default: localhost en DEBUG, Railway en RELEASE)
    init(baseURL: String = defaultBaseURL) {
        self.baseURL = baseURL
        self.httpClient = HTTPClient()
        self.authService = AuthService(client: httpClient, baseURL: baseURL)
    }
    
    // MARK: - APIClientProtocol
    
    func signInWithApple(identityToken: String) async throws -> AuthResponse {
        return try await authService.signInWithApple(identityToken: identityToken)
    }
    
    func generateKit(from request: AIGenerateKitRequest, token: String) async throws -> AIGenerateKitResponse {
        let url = URL(string: "\(baseURL)/ai/chat-sync")!
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
        
        // Debug: imprimir respuesta del servidor
        #if DEBUG
        if let jsonString = String(data: data, encoding: .utf8) {
            print("📥 Backend response: \(jsonString.prefix(2000))")
        }
        #endif
        
        switch httpResponse.statusCode {
        case 200...299:
            let decoder = JSONDecoder.flexibleDateDecoder

            do {
                let response = try decoder.decode(AIGenerateKitResponse.self, from: data)
                #if DEBUG
                print("✅ Kit decodificado: \(response.kit?.title ?? "sin título"), steps: \(response.kit?.steps?.count ?? 0)")
                #endif
                return response
            } catch {
                #if DEBUG
                print("❌ Error de decodificación: \(error)")
                if let decodingError = error as? DecodingError {
                    switch decodingError {
                    case .keyNotFound(let key, let context):
                        print("   Key not found: \(key.stringValue) at \(context.codingPath)")
                    case .typeMismatch(let type, let context):
                        print("   Type mismatch: expected \(type) at \(context.codingPath)")
                    case .valueNotFound(let type, let context):
                        print("   Value not found: \(type) at \(context.codingPath)")
                    case .dataCorrupted(let context):
                        print("   Data corrupted: \(context)")
                    @unknown default:
                        print("   Unknown decoding error")
                    }
                }
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
        let url = URL(string: "\(baseURL)\(path)")!
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
        let url = URL(string: "\(baseURL)/sync/batch")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        urlRequest.httpBody = try encoder.encode(request)

        #if DEBUG
        if let bodyString = String(data: urlRequest.httpBody!, encoding: .utf8) {
            print("📤 Sync request: \(bodyString.prefix(1000))")
        }
        #endif

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        #if DEBUG
        if let jsonString = String(data: data, encoding: .utf8) {
            print("📥 Sync response (\(httpResponse.statusCode)): \(jsonString.prefix(1000))")
        }
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
        let url = URL(string: "\(baseURL)/subscription/verify")!
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
        let url = URL(string: "\(baseURL)/me")!
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
                    let url = URL(string: "\(baseURL)/ai/chat")!
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
