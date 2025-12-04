//
//  Step.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on 13/10/25.
//

import Foundation

// MARK: - Step Description
struct StepDescription: Codable, Hashable, Equatable {
    let short: String
    let long: String
}

// MARK: - Step
struct Step: Identifiable, Hashable, Codable {
    let id: UUID
    let stepTitle: String
    let description: StepDescription
    let estimateMinutes: Int
    let suggestedDeadline: Date?
    let effortLevel: String
    let adaptsTo: String
    let blockedByPremium: Bool
    
    // Computed properties para compatibilidad
    var title: String { stepTitle }
    var isCompleted: Bool = false // Estado local, no viene del backend
    var goalId: UUID? = nil // Para compatibilidad con código existente
    
    enum CodingKeys: String, CodingKey {
        case id
        case stepTitle = "step_title"
        case description
        case estimateMinutes = "estimate_minutes"
        case suggestedDeadline = "suggested_deadline"
        case effortLevel = "effort_level"
        case adaptsTo = "adapts_to"
        case blockedByPremium = "blocked_by_premium"
    }
    
    // MARK: - Custom Decoding
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        stepTitle = try container.decode(String.self, forKey: .stepTitle)
        description = try container.decode(StepDescription.self, forKey: .description)
        estimateMinutes = try container.decode(Int.self, forKey: .estimateMinutes)
        
        // Decodificar fecha como string y convertir a Date
        if let dateString = try? container.decode(String.self, forKey: .suggestedDeadline) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            suggestedDeadline = formatter.date(from: dateString)
        } else {
            suggestedDeadline = nil
        }
        
        effortLevel = try container.decode(String.self, forKey: .effortLevel)
        adaptsTo = try container.decode(String.self, forKey: .adaptsTo)
        blockedByPremium = try container.decode(Bool.self, forKey: .blockedByPremium)
        isCompleted = false
        goalId = nil
    }
    
    // MARK: - Custom Encoding
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(stepTitle, forKey: .stepTitle)
        try container.encode(description, forKey: .description)
        try container.encode(estimateMinutes, forKey: .estimateMinutes)
        
        // Codificar fecha como string
        if let deadline = suggestedDeadline {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            try container.encode(formatter.string(from: deadline), forKey: .suggestedDeadline)
        }
        
        try container.encode(effortLevel, forKey: .effortLevel)
        try container.encode(adaptsTo, forKey: .adaptsTo)
        try container.encode(blockedByPremium, forKey: .blockedByPremium)
    }
    
    // MARK: - Hashable (excluyendo propiedades no-Codable)
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(stepTitle)
        hasher.combine(description)
        hasher.combine(estimateMinutes)
        hasher.combine(suggestedDeadline)
        hasher.combine(effortLevel)
        hasher.combine(adaptsTo)
        hasher.combine(blockedByPremium)
    }
    
    // MARK: - Equatable (excluyendo propiedades no-Codable)
    static func == (lhs: Step, rhs: Step) -> Bool {
        lhs.id == rhs.id &&
        lhs.stepTitle == rhs.stepTitle &&
        lhs.description == rhs.description &&
        lhs.estimateMinutes == rhs.estimateMinutes &&
        lhs.suggestedDeadline == rhs.suggestedDeadline &&
        lhs.effortLevel == rhs.effortLevel &&
        lhs.adaptsTo == rhs.adaptsTo &&
        lhs.blockedByPremium == rhs.blockedByPremium
    }
    
    // MARK: - Convenience Initializer
    init(id: UUID = UUID(), stepTitle: String, description: StepDescription, estimateMinutes: Int, suggestedDeadline: Date?, effortLevel: String, adaptsTo: String, blockedByPremium: Bool, isCompleted: Bool = false, goalId: UUID? = nil) {
        self.id = id
        self.stepTitle = stepTitle
        self.description = description
        self.estimateMinutes = estimateMinutes
        self.suggestedDeadline = suggestedDeadline
        self.effortLevel = effortLevel
        self.adaptsTo = adaptsTo
        self.blockedByPremium = blockedByPremium
        self.isCompleted = isCompleted
        self.goalId = goalId
    }
    
    // MARK: - Preview Data
    static let preview = Step(
        stepTitle: "Paso 1",
        description: StepDescription(short: "Descripción corta", long: "Descripción larga del paso"),
        estimateMinutes: 45,
        suggestedDeadline: Date(),
        effortLevel: "medium",
        adaptsTo: "Se adapta a tu disponibilidad",
        blockedByPremium: false
    )
    
    static let previewPending = Step(
        stepTitle: "Paso 2",
        description: StepDescription(short: "Descripción corta", long: "Descripción larga del paso"),
        estimateMinutes: 60,
        suggestedDeadline: Calendar.current.date(byAdding: .day, value: 1, to: Date()),
        effortLevel: "high",
        adaptsTo: "Requiere tiempo dedicado",
        blockedByPremium: false
    )
}
