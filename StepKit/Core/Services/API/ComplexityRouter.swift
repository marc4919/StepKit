//
//  ComplexityRouter.swift
//  StepKit
//
//  Servicio que usa Apple Foundation Models para determinar
//  si un objetivo requiere un modelo pesado o ligero
//

import Foundation
import FoundationModels

// MARK: - Model Recommendation (from Foundation Model)

@Generable(
    description: "Recommendation for which AI model to use based on goal complexity analysis."
)
struct ModelRecommendation {
    @Guide(description: "Recommended model", .anyOf(["lightweight", "heavyweight"]))
    var recommendedModel: String
    
    @Guide(
        description: "Confidence level in the recommendation (0-100).",
        .range(0...100)
    )
    var confidence: Int
    
    @Guide(description: "1-2 sentence explanation in same language as goal_description.")
    var reasoning: String
}

// MARK: - Complexity Router Service

/// Servicio que evalúa la complejidad de un objetivo usando Apple Intelligence
actor ComplexityRouter {
    
    /// Referencia al modelo del sistema para verificar disponibilidad
    private let model = SystemLanguageModel.default
    
    /// Instrucciones para el modelo router
    private let routerInstructions = Instructions { """
    Analyze a goal to recommend which AI model should generate the roadmap.

    INPUT: goal_description, dueDate, today, inconveniences (optional)

    OUTPUT:
    - recommendedModel: "lightweight" or "heavyweight"
    - confidence: 0-100
    - reasoning: 1-2 sentences (same language as goal_description)

    SCORING SYSTEM (sum the points):

    HORIZON:
    - ≤14 days: 0 points
    - 15-30 days: +1 point
    - >30 days: +2 points

    INCONVENIENCES:
    - None or simple (location, equipment): 0 points
    - Moderate (time constraints, mild physical): +1 point
    - Complex (disabilities, medical, cognitive): +2 points

    DOMAIN COMPLEXITY:
    - Linear domains (home, habit, travel, finance): 0 points
    - Progressive domains (fitness, learning, techSkill, career, creative): +2 points

    GOAL CLARITY:
    - Specific outcome ("run 5km", "read 3 books"): 0 points
    - Vague outcome ("get better at", "improve my", "learn about"): +1 point

    SAFETY FACTOR:
    - No physical/health risk: 0 points
    - Physical activity, nutrition, or tools involved: +1 point

    DECISION:
    - 0-2 points → lightweight (confidence: 90-100)
    - 3-4 points → lightweight (confidence: 60-80)
    - 5-6 points → heavyweight (confidence: 60-80)
    - 7+ points → heavyweight (confidence: 90-100)
    """ }
    
    /// Resultado del análisis de complejidad
    struct ComplexityResult {
        let useHeavyweight: Bool
        let confidence: Int
        let reasoning: String
    }
    
    /// Analiza un objetivo y determina qué tipo de modelo usar
    /// - Parameters:
    ///   - goal: Descripción del objetivo
    ///   - dueDate: Fecha límite
    ///   - obstacles: Lista de obstáculos/inconvenientes
    /// - Returns: Resultado con la recomendación
    func analyzeComplexity(
        goal: String,
        dueDate: Date,
        obstacles: [String]
    ) async -> ComplexityResult {
        // Verificar disponibilidad del modelo antes de intentar usarlo
        guard model.availability == .available else {
            #if DEBUG
            print("⚠️ ComplexityRouter: Foundation Model unavailable → using LIGHTWEIGHT")
            #endif
            return ComplexityResult(
                useHeavyweight: false,
                confidence: 0,
                reasoning: "Default: Foundation model unavailable"
            )
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        let dueDateStr = formatter.string(from: dueDate)
        
        do {
            let session = LanguageModelSession(instructions: routerInstructions)
            
            let prompt = """
            goal_description: \(goal), \
            dueDate: \(dueDateStr), \
            today: \(today), \
            inconveniences: \(obstacles.isEmpty ? "ninguno" : obstacles.joined(separator: ", "))
            """
            
            let recommendation = try await session.respond(
                to: prompt,
                generating: ModelRecommendation.self
            ).content
            
            let useHeavyweight = recommendation.recommendedModel == "heavyweight"

            #if DEBUG
            print(
                "🧠 ComplexityRouter: model=\(useHeavyweight ? "heavyweight" : "lightweight"), " +
                "confidence=\(recommendation.confidence)"
            )
            #endif

            return ComplexityResult(
                useHeavyweight: useHeavyweight,
                confidence: recommendation.confidence,
                reasoning: recommendation.reasoning
            )
            
        } catch {
            #if DEBUG
            print(
                "⚠️ ComplexityRouter: fallback=lightweight, " +
                "errorType=\(String(describing: type(of: error)))"
            )
            #endif
            return ComplexityResult(
                useHeavyweight: false,
                confidence: 0,
                reasoning: "Default: Foundation model error"
            )
        }
    }
}

// MARK: - Singleton for easy access

extension ComplexityRouter {
    /// Instancia compartida del router
    static let shared = ComplexityRouter()
}
