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
    private let baseURL: String
    
    /// Inicializa el cliente con una URL base
    /// - Parameter baseURL: URL base del servidor (default: localhost para desarrollo)
    init(baseURL: String = "http://localhost:8080") {
        self.baseURL = baseURL
    }
    
    // MARK: - APIClientProtocol
    
    func signInWithApple(identityToken: String) async throws -> AuthResponse {
        let url = URL(string: "\(baseURL)/auth/apple")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["identityToken": identityToken]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.serverError(httpResponse.statusCode, errorMessage)
        }
        
        return try JSONDecoder().decode(AuthResponse.self, from: data)
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
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                
                // Intentar varios formatos de fecha
                let formatters = [
                    "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
                    "yyyy-MM-dd'T'HH:mm:ssZ",
                    "yyyy-MM-dd'T'HH:mm:ss",
                    "yyyy-MM-dd"
                ]
                
                for format in formatters {
                    let formatter = DateFormatter()
                    formatter.dateFormat = format
                    formatter.locale = Locale(identifier: "en_US_POSIX")
                    if let date = formatter.date(from: dateString) {
                        return date
                    }
                }
                
                // Si es ISO8601 estándar
                if let date = ISO8601DateFormatter().date(from: dateString) {
                    return date
                }
                
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(dateString)")
            }
            
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
}

// MARK: - Response Models

/// Respuesta del endpoint de autenticación
struct AuthResponse: Codable {
    let token: String
    let user: UserInfo
}

/// Información del usuario devuelta por el backend
struct UserInfo: Codable {
    let id: String // UUID como string desde JSON
    let tier: String
    let monthlyTokensUsed: Int
    let monthlyTokenQuota: Int
    
    /// Convierte el id string a UUID
    var uuid: UUID? {
        UUID(uuidString: id)
    }
}

// MARK: - Error Types

enum APIError: Error, LocalizedError {
    case invalidResponse
    case serverError(Int, String)
    case notAuthenticated
    case networkError(Error)
    case decodingError(Error)
    case premiumRequired
    case quotaExceeded
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Respuesta inválida del servidor"
        case .serverError(let code, let message):
            return "Error del servidor (\(code)): \(message)"
        case .notAuthenticated:
            return "No estás autenticado"
        case .networkError(let error):
            return "Error de red: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Error al procesar la respuesta: \(error.localizedDescription)"
        case .premiumRequired:
            return "Esta función requiere una suscripción premium"
        case .quotaExceeded:
            return "Has alcanzado el límite de uso mensual"
        }
    }
}

