//
//  APIService.swift
//  StepKit
//
//  Tipos compartidos para el API Client
//

import Foundation

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

    var isPremium: Bool {
        tier == "premium"
    }
}

/// Respuesta del endpoint de verificación de suscripción
struct VerifySubscriptionResponse: Codable {
    let tier: String
    let expiresAt: Date?
    let status: String?
    let productId: String?
}

/// Límites del usuario devueltos por /me
struct UserLimits: Codable {
    let monthlyTokenQuota: Int
    let monthlyTokensUsed: Int
    let maxActiveGoalsFree: Int
    let monthlyAICalls: Int
    let monthlyAICallsQuota: Int
    let activeKitsCount: Int

    var aiCallsRemaining: Int {
        max(0, monthlyAICallsQuota - monthlyAICalls)
    }

    var canCreateKit: Bool {
        activeKitsCount < maxActiveGoalsFree
    }

    var canUseAI: Bool {
        monthlyAICalls < monthlyAICallsQuota
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
