//
//  GoalEntity.swift
//  StepKit
//
//  Modelo SwiftData para persistencia local de Goals (Kits)
//

import Foundation
import SwiftData

@Model
final class GoalEntity {
    @Attribute(.unique) var id: UUID
    var planTitle: String
    var horizonDays: Int
    var kpi: String
    var metaType: String
    var metaTags: [String]
    var risks: [String]
    var version: Int
    var progress: Double
    var sourceModel: String?
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    var isDeleted: Bool
    
    @Relationship(deleteRule: .cascade, inverse: \StepEntity.goal)
    var steps: [StepEntity] = []
    
    init(
        id: UUID = UUID(),
        planTitle: String,
        horizonDays: Int,
        kpi: String,
        metaType: String = "personal",
        metaTags: [String] = [],
        risks: [String] = [],
        version: Int = 1,
        progress: Double = 0.0,
        sourceModel: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deletedAt: Date? = nil,
        isDeleted: Bool = false
    ) {
        self.id = id
        self.planTitle = planTitle
        self.horizonDays = horizonDays
        self.kpi = kpi
        self.metaType = metaType
        self.metaTags = metaTags
        self.risks = risks
        self.version = version
        self.progress = progress
        self.sourceModel = sourceModel
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.isDeleted = isDeleted
    }
    
    // MARK: - Conversion from KitDTO
    
    convenience init(from dto: KitDTO) {
        self.init(
            id: dto.id ?? UUID(),
            planTitle: dto.title,
            horizonDays: dto.horizonDays,
            kpi: dto.kpi,
            metaType: dto.metaType,
            metaTags: dto.metaTags,
            risks: dto.risks,
            version: dto.version,
            progress: dto.progress ?? 0.0,
            sourceModel: dto.sourceModel,
            createdAt: dto.createdAt ?? Date(),
            updatedAt: dto.updatedAt,
            deletedAt: dto.deletedAt,
            isDeleted: dto.deleted
        )
    }
    
    // MARK: - Conversion to Goal (view model)
    
    func toGoal() -> Goal {
        let sortedSteps = steps.sorted { $0.order < $1.order }.map { $0.toStep() }
        
        return Goal(
            id: id,
            planTitle: planTitle,
            horizonDays: horizonDays,
            kpi: kpi,
            meta: PlanMetadata(type: metaType, tags: metaTags),
            risks: risks,
            steps: sortedSteps
        )
    }
    
    // MARK: - Computed Properties
    
    var title: String { planTitle }
    
    var computedProgress: Double {
        guard !steps.isEmpty else { return 0.0 }
        let completed = steps.filter { $0.isCompleted }.count
        return Double(completed) / Double(steps.count)
    }
    
    var isCompleted: Bool {
        !steps.isEmpty && steps.allSatisfy { $0.isCompleted }
    }
    
    var dueDate: Date? {
        steps.compactMap { $0.suggestedDeadline }.max()
    }
}

