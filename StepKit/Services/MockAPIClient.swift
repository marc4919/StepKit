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
        return mockKitResponse ?? createMockKitResponse(from: request)
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
    
    // MARK: - Mock Data Generators
    
    private func createMockKitResponse(from request: AIGenerateKitRequest) -> AIGenerateKitResponse {
        let kitId = UUID()
        let now = Date()
        
        // Crear pasos mock basados en la descripción
        let steps = createMockSteps(for: kitId, goalDescription: request.goalDescription, dueDate: request.dueDate)
        
        let kit = KitDTO(
            id: kitId,
            userId: nil,
            title: "Plan: \(request.goalDescription.prefix(50))",
            kpi: "Completar todos los pasos del plan",
            horizonDays: Calendar.current.dateComponents([.day], from: now, to: dateFromString(request.dueDate) ?? now).day ?? 30,
            metaType: "personal",
            metaTags: ["generated", "ai"],
            risks: request.inconveniences,
            version: 1,
            progress: 0.0,
            sourceModel: "mock-model",
            promptVersion: 1,
            rawArguments: nil,
            createdAt: now,
            updatedAt: now,
            deletedAt: nil,
            deleted: false,
            steps: steps
        )
        
        return AIGenerateKitResponse(
            kit: kit,
            rawResponse: "Mock response",
            usage: UsageDTO(tokensIn: 150, tokensOut: 500, model: "mock-model")
        )
    }
    
    private func createMockSteps(for kitId: UUID, goalDescription: String, dueDate: String) -> [StepDTO] {
        let now = Date()
        let targetDate = dateFromString(dueDate) ?? Calendar.current.date(byAdding: .day, value: 30, to: now)!
        let totalDays = Calendar.current.dateComponents([.day], from: now, to: targetDate).day ?? 30
        
        return [
            StepDTO(
                id: UUID(),
                kitId: kitId,
                title: "Investigar y planificar",
                descriptionShort: "Investiga sobre '\(goalDescription.prefix(30))' y crea un plan inicial",
                descriptionLong: "Dedica tiempo a investigar los fundamentos y mejores prácticas relacionadas con tu objetivo. Crea un plan detallado con hitos intermedios.",
                estimateMinutes: 45,
                suggestedDeadline: Calendar.current.date(byAdding: .day, value: max(1, totalDays / 5), to: now),
                effortLevel: "medium",
                adaptsTo: "Puedes dividirlo en sesiones más cortas",
                blockedByPremium: false,
                order: 0,
                completed: false,
                createdAt: now,
                updatedAt: now,
                deletedAt: nil
            ),
            StepDTO(
                id: UUID(),
                kitId: kitId,
                title: "Primeros pasos prácticos",
                descriptionShort: "Empieza con las acciones básicas",
                descriptionLong: "Comienza a practicar o ejecutar las primeras acciones hacia tu objetivo. No te preocupes por la perfección, enfócate en el progreso.",
                estimateMinutes: 60,
                suggestedDeadline: Calendar.current.date(byAdding: .day, value: max(2, totalDays * 2 / 5), to: now),
                effortLevel: "medium",
                adaptsTo: "Ajusta la intensidad según tu disponibilidad",
                blockedByPremium: false,
                order: 1,
                completed: false,
                createdAt: now,
                updatedAt: now,
                deletedAt: nil
            ),
            StepDTO(
                id: UUID(),
                kitId: kitId,
                title: "Consolidar el progreso",
                descriptionShort: "Refuerza lo aprendido y avanza",
                descriptionLong: "Revisa tu progreso, identifica áreas de mejora y continúa avanzando. Este es el momento de ajustar tu enfoque si es necesario.",
                estimateMinutes: 45,
                suggestedDeadline: Calendar.current.date(byAdding: .day, value: max(3, totalDays * 3 / 5), to: now),
                effortLevel: "medium",
                adaptsTo: "Puedes hacer revisiones más frecuentes si lo prefieres",
                blockedByPremium: false,
                order: 2,
                completed: false,
                createdAt: now,
                updatedAt: now,
                deletedAt: nil
            ),
            StepDTO(
                id: UUID(),
                kitId: kitId,
                title: "Completar el objetivo",
                descriptionShort: "Finaliza y evalúa tu progreso",
                descriptionLong: "Realiza las acciones finales para completar tu objetivo. Evalúa lo que has aprendido y celebra tu logro.",
                estimateMinutes: 30,
                suggestedDeadline: targetDate,
                effortLevel: "low",
                adaptsTo: "Dedica el tiempo necesario para una buena evaluación final",
                blockedByPremium: false,
                order: 3,
                completed: false,
                createdAt: now,
                updatedAt: now,
                deletedAt: nil
            )
        ]
    }
    
    private func dateFromString(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString)
    }
}

