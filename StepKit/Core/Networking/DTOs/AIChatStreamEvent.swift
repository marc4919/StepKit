//
//  AIChatStreamEvent.swift
//  StepKit
//
//  DTOs para eventos de streaming SSE desde el backend
//

import Foundation

/// Evento SSE para streaming de creación de kits
/// Tipos: "plan_mode" | "kit_info" | "step" | "restart" | "done" | "error"
struct AIChatStreamEvent: Codable {
    let type: String

    // Para type = "plan_mode": "normal" | "careful" y los motivos del modo cuidado
    var mode: String? = nil
    var reasons: [String]? = nil

    // Para type = "kit_info"
    let kitTitle: String?
    let kpi: String?
    let horizonDays: Int?
    let risks: [String]?
    
    // Para type = "step"
    let step: StreamStepOutput?
    let stepIndex: Int?
    let totalSteps: Int?
    
    // Para type = "done"
    let kitId: UUID?
    let kit: KitDTO?
    let usage: UsageDTO?
    
    // Para type = "error"
    let error: String?
    
    /// Tipo de evento
    var eventType: EventType {
        EventType(rawValue: type) ?? .unknown
    }
    
    enum EventType: String {
        case planMode = "plan_mode"
        case kitInfo = "kit_info"
        case step = "step"
        case restart = "restart"
        case done = "done"
        case error = "error"
        case unknown
    }
}

/// Step output del streaming (diferente del StepDTO completo)
struct StreamStepOutput: Codable {
    let stepTitle: String
    let description: StreamDescriptionOutput
    let estimateMinutes: Int
    let suggestedDeadline: String // YYYY-MM-DD
    let effortLevel: String
    let adaptsTo: String
    let blockedByPremium: Bool
    
    // El backend envía snake_case
    enum CodingKeys: String, CodingKey {
        case stepTitle = "step_title"
        case description
        case estimateMinutes = "estimate_minutes"
        case suggestedDeadline = "suggested_deadline"
        case effortLevel = "effort_level"
        case adaptsTo = "adapts_to"
        case blockedByPremium = "blocked_by_premium"
    }
    
    /// Convierte a Step local
    func toStep(index: Int) -> Step {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let deadline = formatter.date(from: suggestedDeadline)
        
        return Step(
            id: UUID(),
            stepTitle: stepTitle,
            description: StepDescription(short: description.short, long: description.long),
            estimateMinutes: estimateMinutes,
            suggestedDeadline: deadline,
            effortLevel: effortLevel,
            adaptsTo: adaptsTo,
            blockedByPremium: blockedByPremium,
            isCompleted: false,
            goalId: nil
        )
    }
}

struct StreamDescriptionOutput: Codable {
    let short: String
    let long: String
}

