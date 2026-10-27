//
//  APIService.swift
//  StepKit
//
//  Tipos compartidos para el API Client
//

import Foundation

// MARK: - Response Models

/// Respuesta del endpoint de autenticación
nonisolated struct AuthResponse: Codable {
    let token: String
    let user: UserInfo
}

/// Información del usuario simplificada (usada en Auth y persistencia)
struct UserInfo: Codable {
    let id: String // UUID como string
    let tier: String
    let monthlyTokensUsed: Int
    let monthlyTokenQuota: Int
    
    // Campos opcionales que vienen del perfil completo
    var monthlyAICalls: Int?
    var monthlyAICallsQuota: Int?
    var activeKitsCount: Int?

    /// Convierte el id string a UUID
    var uuid: UUID? {
        UUID(uuidString: id)
    }

    var isPremium: Bool {
        tier == "premium"
    }
    
    init(id: String, tier: String, monthlyTokensUsed: Int, monthlyTokenQuota: Int, monthlyAICalls: Int? = nil, monthlyAICallsQuota: Int? = nil, activeKitsCount: Int? = nil) {
        self.id = id
        self.tier = tier
        self.monthlyTokensUsed = monthlyTokensUsed
        self.monthlyTokenQuota = monthlyTokenQuota
        self.monthlyAICalls = monthlyAICalls
        self.monthlyAICallsQuota = monthlyAICallsQuota
        self.activeKitsCount = activeKitsCount
    }
    
    init(from profile: UserProfileResponse) {
        self.id = profile.id.uuidString
        self.tier = profile.tier
        self.monthlyTokensUsed = profile.limits.monthlyTokensUsed
        self.monthlyTokenQuota = profile.limits.monthlyTokenQuota
        self.monthlyAICalls = profile.limits.monthlyAICalls
        self.monthlyAICallsQuota = profile.limits.monthlyAICallsQuota
        self.activeKitsCount = profile.limits.activeKitsCount
    }
}

/// Respuesta completa del perfil de usuario (GET /me)
struct UserProfileResponse: Codable {
    let id: UUID
    let tier: String
    let subscription: SubscriptionInfo?
    let limits: UserLimits
    let aiUsageMonth: AIUsageMonth?
}

struct SubscriptionInfo: Codable {
    let status: String
    let expiresAt: Date?
    let productId: String?
    let autoRenewEnabled: Bool?
}

struct AIUsageMonth: Codable {
    let month: String
    let tokensIn: Int
    let tokensOut: Int
    let requests: Int
}

/// Respuesta del endpoint de verificación de suscripción
nonisolated struct VerifySubscriptionResponse: Codable {
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

enum APIError: Error, LocalizedError, CustomStringConvertible {
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
            return String(localized: "Respuesta inválida del servidor")
        case .serverError(let code, _):
            return String(localized: "Error del servidor (\(code))")
        case .notAuthenticated:
            return String(localized: "No estás autenticado")
        case .networkError(let error):
            return String(localized: "Error de red: \(error.localizedDescription)")
        case .decodingError(let error):
            return String(localized: "Error al procesar la respuesta: \(error.localizedDescription)")
        case .premiumRequired:
            return String(localized: "Esta función requiere una suscripción premium")
        case .quotaExceeded:
            return String(localized: "Has alcanzado el límite de uso mensual")
        }
    }

    var description: String {
        errorDescription ?? String(localized: "Error de API")
    }
}
