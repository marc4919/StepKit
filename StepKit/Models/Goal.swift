//
//  Goal.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on 13/10/25.
//

import Foundation

// MARK: - Plan Metadata
struct PlanMetadata: Codable, Hashable, Equatable {
    let type: String
    let tags: [String]
}

// MARK: - Plan (Kit)
struct Goal: Identifiable, Hashable, Codable {
    let id: UUID
    let planTitle: String
    let horizonDays: Int
    let kpi: String
    let meta: PlanMetadata
    let risks: [String]
    let steps: [Step]
    
    // Computed properties para compatibilidad
    var title: String { planTitle }
    var description: String { kpi }
    var progress: Double {
        guard !steps.isEmpty else { return 0.0 }
        let completed = steps.filter { $0.isCompleted }.count
        return Double(completed) / Double(steps.count)
    }
    var isCompleted: Bool {
        !steps.isEmpty && steps.allSatisfy { $0.isCompleted }
    }
    var dueDate: Date? {
        // Usar la fecha más lejana de los pasos
        steps.compactMap { $0.suggestedDeadline }.max()
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case planTitle = "plan_title"
        case horizonDays = "horizon_days"
        case kpi
        case meta
        case risks
        case steps
    }
    
    // MARK: - Initializer
    init(id: UUID = UUID(), planTitle: String, horizonDays: Int, kpi: String, meta: PlanMetadata, risks: [String], steps: [Step]) {
        self.id = id
        self.planTitle = planTitle
        self.horizonDays = horizonDays
        self.kpi = kpi
        self.meta = meta
        self.risks = risks
        self.steps = steps
    }
    
    // MARK: - Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(planTitle)
        hasher.combine(horizonDays)
        hasher.combine(kpi)
        hasher.combine(meta)
        hasher.combine(risks)
        hasher.combine(steps)
    }
    
    // MARK: - Equatable
    static func == (lhs: Goal, rhs: Goal) -> Bool {
        lhs.id == rhs.id &&
        lhs.planTitle == rhs.planTitle &&
        lhs.horizonDays == rhs.horizonDays &&
        lhs.kpi == rhs.kpi &&
        lhs.meta == rhs.meta &&
        lhs.risks == rhs.risks &&
        lhs.steps == rhs.steps
    }
    
    // MARK: - Preview Data
    static let preview = Goal(
        id: UUID(),
        planTitle: "Aprender SwiftUI",
        horizonDays: 42,
        kpi: "Completar 5 proyectos funcionales",
        meta: PlanMetadata(type: "learning", tags: ["technical", "desk"]),
        risks: ["Falta de tiempo", "Curva de aprendizaje"],
        steps: []
    )
    
    static let previewCompleted = Goal(
        id: UUID(),
        planTitle: "Configurar proyecto",
        horizonDays: 7,
        kpi: "Proyecto funcionando",
        meta: PlanMetadata(type: "setup", tags: []),
        risks: [],
        steps: []
    )
}
