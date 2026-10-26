//
//  AIGenerateKitDTO.swift
//  StepKit
//
//  DTOs para comunicación con el endpoint /ai/chat-sync del backend
//  NOTA: Vapor usa camelCase por defecto en JSON, así que no necesitamos CodingKeys custom
//

import Foundation

// MARK: - Request

/// Petición para generar un kit con IA
/// Mapea 1:1 con AIRequest del backend
struct AIGenerateKitRequest: Codable {
    let goalDescription: String
    let dueDate: String // YYYY-MM-DD
    let today: String // YYYY-MM-DD
    let timezone: String
    let dailyAvailableTime: Int // minutos
    let maxStepsPerDay: Int
    let inconveniences: [String]
    let progressState: String // "just starting", "in progress", "almost done"
    let complexityScore: Double // 0.0-1.0
    let promptVersion: Int // 1 = heavyweight, 2 = lightweight
    /// La app sabe mostrar «Ajustando tu plan…» si el servidor reinicia con otro modelo.
    var supportsRestart = true
    /// En Kits delicados el servidor puede preguntar antes de generar (evento `questions`).
    var supportsQuestions = true
    /// Respuestas a esas preguntas; el servidor no guarda estado, así que va también el texto.
    var answers: [KitAnswer]? = nil
    /// Idioma de la app («es» o «en»): el plan debe escribirse en este idioma.
    var language: String? = AppLanguage.code

    /// Crea un request a partir de los datos del formulario
    /// - Parameters:
    ///   - description: Descripción del objetivo
    ///   - dueDate: Fecha objetivo
    ///   - dailyMinutes: Minutos disponibles al día (default: 60)
    ///   - obstacles: Lista de obstáculos/inconvenientes
    ///   - useHeavyweight: Si usar el modelo pesado (determinado por foundation model)
    init(
        description: String,
        dueDate: Date,
        dailyMinutes: Int = 60,
        obstacles: [String] = [],
        useHeavyweight: Bool = false
    ) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        self.goalDescription = description
        self.dueDate = formatter.string(from: dueDate)
        self.today = formatter.string(from: Date())
        self.timezone = TimeZone.current.identifier
        self.dailyAvailableTime = dailyMinutes
        self.maxStepsPerDay = 3 // Default razonable
        self.inconveniences = obstacles
        self.progressState = "just starting"
        
        // Calcular complejidad basada en días hasta deadline y obstáculos
        let daysUntilDeadline = Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 30
        let baseComplexity = min(1.0, Double(obstacles.count) * 0.15)
        let timeComplexity = daysUntilDeadline < 7 ? 0.3 : (daysUntilDeadline < 30 ? 0.1 : 0.0)
        self.complexityScore = min(1.0, baseComplexity + timeComplexity + 0.3) // Base de 0.3
        
        // Versión del prompt determinada por foundation model
        // 1 = heavyweight (modelo potente), 2 = lightweight (modelo ligero)
        self.promptVersion = useHeavyweight ? 1 : 2
    }
}

/// Respuesta a una pregunta del servidor. En opción múltiple, las opciones van separadas por ", ".
struct KitAnswer: Codable, Hashable {
    let id: String
    let question: String
    let value: String
}

// MARK: - Response

/// Respuesta del endpoint /ai/chat-sync
struct AIGenerateKitResponse: Codable {
    let kit: KitDTO?
    let rawResponse: String
    let usage: UsageDTO
}

/// DTO del Kit devuelto por el backend (Vapor usa camelCase)
struct KitDTO: Codable {
    let id: UUID?
    let userId: UUID?
    let title: String
    let kpi: String
    let horizonDays: Int
    let metaType: String
    let metaTags: [String]
    let risks: [String]
    let version: Int
    let progress: Double?
    let sourceModel: String?
    let promptVersion: Int?
    let rawArguments: String?
    let createdAt: Date?
    let updatedAt: Date
    let deletedAt: Date?
    let deleted: Bool
    let steps: [StepDTO]?
    
    /// Convierte el DTO a un modelo Goal local
    func toGoal() -> Goal {
        let goalSteps = (steps ?? []).map { $0.toStep() }
        
        return Goal(
            id: id ?? UUID(),
            planTitle: title,
            horizonDays: horizonDays,
            kpi: kpi,
            meta: PlanMetadata(type: metaType, tags: metaTags),
            risks: risks,
            steps: goalSteps
        )
    }
}

/// DTO del Step devuelto por el backend (Vapor usa camelCase)
struct StepDTO: Codable {
    let id: UUID?
    let kitId: UUID?
    let title: String
    let descriptionShort: String
    let descriptionLong: String
    let estimateMinutes: Int
    let suggestedDeadline: Date?
    let effortLevel: String
    let adaptsTo: String
    let blockedByPremium: Bool
    let order: Int
    let completed: Bool
    let createdAt: Date?
    let updatedAt: Date?
    let deletedAt: Date?
    /// Paso que se repite ("day" | "week") y cuántas sesiones; nil si es puntual.
    var repeatEvery: String? = nil
    var repeatTimes: Int? = nil
    
    /// Convierte el DTO a un modelo Step local
    func toStep() -> Step {
        Step(
            id: id ?? UUID(),
            stepTitle: title,
            description: StepDescription(short: descriptionShort, long: descriptionLong),
            estimateMinutes: estimateMinutes,
            suggestedDeadline: suggestedDeadline,
            effortLevel: effortLevel,
            adaptsTo: adaptsTo,
            blockedByPremium: blockedByPremium,
            isCompleted: completed,
            goalId: kitId
        )
    }
}

/// Información de uso de tokens
struct UsageDTO: Codable {
    let tokensIn: Int
    let tokensOut: Int
    let model: String
}
