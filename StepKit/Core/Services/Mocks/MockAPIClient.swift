//
//  MockAPIClient.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on [Date]
//

import Foundation

/// Mock del cliente API para tests y previews
/// Permite simular respuestas del backend sin necesidad de un servidor real
final class MockAPIClient: APIClientProtocol {
    // MARK: - Configuration
    
    /// Si es true, el login siempre fallará
    var shouldFailLogin = false
    
    /// Si es true, la generación de kit fallará
    var shouldFailKitGeneration = false
    
    /// Error personalizado para el login
    var loginError: Error?
    
    /// Error personalizado para generación de kit
    var kitGenerationError: Error?
    
    /// Respuesta mock para el login
    var mockAuthResponse: AuthResponse?
    
    /// Respuesta mock para generación de kit
    var mockKitResponse: AIGenerateKitResponse?
    
    /// Delay simulado para simular latencia de red (en segundos)
    var simulatedDelay: TimeInterval = 0.5
    
    /// Delay específico para generación de kit (suele ser más largo)
    var kitGenerationDelay: TimeInterval = 2.0
    
    /// Si es true, la verificación de suscripción fallará
    var shouldFailVerifySubscription = false
    
    /// Error personalizado para verificación de suscripción
    var verifySubscriptionError: Error?
    
    /// Respuesta mock para verificación de suscripción
    var mockVerifySubscriptionResponse: VerifySubscriptionResponse?
    
    // MARK: - APIClientProtocol
    
    func signInWithApple(identityToken: String) async throws -> AuthResponse {
        // Simular latencia de red
        try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        
        // Si hay un error configurado, lanzarlo
        if let error = loginError {
            throw error
        }
        
        // Si debe fallar, lanzar error genérico
        if shouldFailLogin {
            throw APIError.serverError(401, "Invalid identity token")
        }
        
        // Devolver respuesta mock o una por defecto
        return mockAuthResponse ?? AuthResponse(
            token: "mock-jwt-token-\(UUID().uuidString)",
            user: UserInfo(
                id: UUID().uuidString,
                tier: "premium",
                monthlyTokensUsed: 0,
                monthlyTokenQuota: 10000
            )
        )
    }
    
    func generateKit(from request: AIGenerateKitRequest, token: String) async throws -> AIGenerateKitResponse {
        // Simular latencia de red (la IA tarda más)
        try await Task.sleep(nanoseconds: UInt64(kitGenerationDelay * 1_000_000_000))
        
        // Si hay un error configurado, lanzarlo
        if let error = kitGenerationError {
            throw error
        }
        
        // Si debe fallar, lanzar error genérico
        if shouldFailKitGeneration {
            throw APIError.premiumRequired
        }
        
        // Devolver respuesta mock o generar una por defecto
        return mockKitResponse ?? MockDataGenerators.createMockKitResponse(from: request)
    }
    
    func authenticatedRequest(path: String, method: String, token: String) -> URLRequest {
        // Para mocks, simplemente crear un request básico
        let url = URL(string: "https://mock-api.example.com\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }
    
    func streamKitGeneration(from request: AIGenerateKitRequest, token: String) -> AsyncThrowingStream<AIChatStreamEvent, Error> {
        let shouldFail = shouldFailKitGeneration
        let customError = kitGenerationError
        let goalDescription = request.goalDescription
        let dueDate = request.dueDate
        let risks = request.inconveniences
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    // Simular delay inicial
                    try await Task.sleep(nanoseconds: 300_000_000) // 300ms
                    
                    // Si debe fallar
                    if let error = customError {
                        throw error
                    }
                    if shouldFail {
                        throw APIError.premiumRequired
                    }
                    
                    let kitId = UUID()
                    let now = Date()
                    let targetDate = MockDataGenerators.dateFromString(dueDate) ?? Calendar.current.date(byAdding: .day, value: 30, to: now)!
                    let horizonDays = Calendar.current.dateComponents([.day], from: now, to: targetDate).day ?? 30
                    
                    // Emitir kit_info
                    let kitInfoEvent = AIChatStreamEvent(
                        type: "kit_info",
                        kitTitle: "Plan: \(goalDescription.prefix(50))",
                        kpi: "Completar todos los pasos del plan",
                        horizonDays: horizonDays,
                        risks: risks,
                        step: nil,
                        stepIndex: nil,
                        totalSteps: nil,
                        kitId: nil,
                        kit: nil,
                        usage: nil,
                        error: nil
                    )
                    continuation.yield(kitInfoEvent)
                    
                    try await Task.sleep(nanoseconds: 200_000_000) // 200ms
                    
                    // Crear y emitir steps uno a uno
                    let mockSteps = MockDataGenerators.createMockStreamSteps(goalDescription: goalDescription, dueDate: dueDate)
                    
                    for (index, step) in mockSteps.enumerated() {
                        let stepEvent = AIChatStreamEvent(
                            type: "step",
                            kitTitle: nil,
                            kpi: nil,
                            horizonDays: nil,
                            risks: nil,
                            step: step,
                            stepIndex: index,
                            totalSteps: mockSteps.count,
                            kitId: nil,
                            kit: nil,
                            usage: nil,
                            error: nil
                        )
                        continuation.yield(stepEvent)
                        
                        try await Task.sleep(nanoseconds: 300_000_000) // 300ms entre steps
                    }
                    
                    // Emitir done con el kit completo
                    let kitDTO = MockDataGenerators.createMockKitDTO(kitId: kitId, goalDescription: goalDescription, dueDate: dueDate, risks: risks)
                    let usage = UsageDTO(tokensIn: 150, tokensOut: 500, model: "mock-model")
                    
                    let doneEvent = AIChatStreamEvent(
                        type: "done",
                        kitTitle: nil,
                        kpi: nil,
                        horizonDays: nil,
                        risks: nil,
                        step: nil,
                        stepIndex: nil,
                        totalSteps: nil,
                        kitId: kitId,
                        kit: kitDTO,
                        usage: usage,
                        error: nil
                    )
                    continuation.yield(doneEvent)
                    
                    continuation.finish()
                } catch {
                    let errorEvent = AIChatStreamEvent(
                        type: "error",
                        kitTitle: nil,
                        kpi: nil,
                        horizonDays: nil,
                        risks: nil,
                        step: nil,
                        stepIndex: nil,
                        totalSteps: nil,
                        kitId: nil,
                        kit: nil,
                        usage: nil,
                        error: error.localizedDescription
                    )
                    continuation.yield(errorEvent)
                    continuation.finish()
                }
            }
        }
    }
    
    func verifySubscription(transactionId: String, token: String) async throws -> VerifySubscriptionResponse {
        // Simular latencia
        try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        
        if let error = verifySubscriptionError {
            throw error
        }
        
        if shouldFailVerifySubscription {
            throw APIError.serverError(400, "Invalid transaction")
        }
        
        return mockVerifySubscriptionResponse ?? VerifySubscriptionResponse(
            tier: "premium",
            expiresAt: Calendar.current.date(byAdding: .month, value: 1, to: Date()),
            status: "active",
            productId: "com.stepkit.premium.monthly"
        )
    }
}

