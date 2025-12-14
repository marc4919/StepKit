//
//  StepEntity.swift
//  StepKit
//
//  Modelo SwiftData para persistencia local de Steps
//

import Foundation
import SwiftData

@Model
final class StepEntity {
    @Attribute(.unique) var id: UUID
    var stepTitle: String
    var descriptionShort: String
    var descriptionLong: String
    var estimateMinutes: Int
    var suggestedDeadline: Date?
    var effortLevel: String
    var adaptsTo: String
    var blockedByPremium: Bool
    var order: Int
    var isCompleted: Bool
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    var notificationEnabled: Bool

    var goal: GoalEntity?
    
    init(
        id: UUID = UUID(),
        stepTitle: String,
        descriptionShort: String,
        descriptionLong: String,
        estimateMinutes: Int,
        suggestedDeadline: Date? = nil,
        effortLevel: String = "medium",
        adaptsTo: String = "",
        blockedByPremium: Bool = false,
        order: Int = 0,
        isCompleted: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deletedAt: Date? = nil,
        notificationEnabled: Bool = true
    ) {
        self.id = id
        self.stepTitle = stepTitle
        self.descriptionShort = descriptionShort
        self.descriptionLong = descriptionLong
        self.estimateMinutes = estimateMinutes
        self.suggestedDeadline = suggestedDeadline
        self.effortLevel = effortLevel
        self.adaptsTo = adaptsTo
        self.blockedByPremium = blockedByPremium
        self.order = order
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.notificationEnabled = notificationEnabled
    }

    // MARK: - Conversion from StepDTO
    
    convenience init(from dto: StepDTO, goal: GoalEntity) {
        self.init(
            id: dto.id ?? UUID(),
            stepTitle: dto.title,
            descriptionShort: dto.descriptionShort,
            descriptionLong: dto.descriptionLong,
            estimateMinutes: dto.estimateMinutes,
            suggestedDeadline: dto.suggestedDeadline,
            effortLevel: dto.effortLevel,
            adaptsTo: dto.adaptsTo,
            blockedByPremium: dto.blockedByPremium,
            order: dto.order,
            isCompleted: dto.completed,
            createdAt: dto.createdAt ?? Date(),
            updatedAt: dto.updatedAt ?? Date(),
            deletedAt: dto.deletedAt
        )
        self.goal = goal
    }
    
    // MARK: - Conversion to Step (view model)
    
    func toStep() -> Step {
        Step(
            id: id,
            stepTitle: stepTitle,
            description: StepDescription(short: descriptionShort, long: descriptionLong),
            estimateMinutes: estimateMinutes,
            suggestedDeadline: suggestedDeadline,
            effortLevel: effortLevel,
            adaptsTo: adaptsTo,
            blockedByPremium: blockedByPremium,
            isCompleted: isCompleted,
            goalId: goal?.id
        )
    }
    
    // MARK: - Computed Properties

    var title: String { stepTitle }

    // MARK: - Modification Tracking

    /// Marca la entidad como modificada localmente (actualiza timestamp)
    func markModified() {
        updatedAt = Date()
        // También marca el goal parent como modificado
        goal?.markModified()
    }

    // MARK: - Sync Conversion

    /// Convierte la entidad a DTO para sincronización
    func toSyncDTO() -> StepSyncDTO {
        StepSyncDTO(
            id: id,
            kitId: goal?.id ?? UUID(),
            title: stepTitle,
            descriptionShort: descriptionShort,
            descriptionLong: descriptionLong,
            estimateMinutes: estimateMinutes,
            suggestedDeadline: suggestedDeadline,
            effortLevel: effortLevel,
            adaptsTo: adaptsTo,
            blockedByPremium: blockedByPremium,
            order: order,
            completed: isCompleted,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt
    }

    /// Actualiza la entidad desde un DTO del servidor
    func update(from dto: StepSyncDTO) {
        stepTitle = dto.title
        descriptionShort = dto.descriptionShort
        descriptionLong = dto.descriptionLong
        estimateMinutes = dto.estimateMinutes
        suggestedDeadline = dto.suggestedDeadline
        effortLevel = dto.effortLevel
        adaptsTo = dto.adaptsTo
        blockedByPremium = dto.blockedByPremium
        order = dto.order
        isCompleted = dto.completed
        createdAt = dto.createdAt ?? createdAt
        updatedAt = dto.updatedAt ?? updatedAt
        deletedAt = dto.deletedAt
    }

    /// Crea una entidad desde un DTO de sync
    convenience init(fromSync dto: StepSyncDTO, goal: GoalEntity) {
        self.init(
            id: dto.id ?? UUID(),
            stepTitle: dto.title,
            descriptionShort: dto.descriptionShort,
            descriptionLong: dto.descriptionLong,
            estimateMinutes: dto.estimateMinutes,
            suggestedDeadline: dto.suggestedDeadline,
            effortLevel: dto.effortLevel,
            adaptsTo: dto.adaptsTo,
            blockedByPremium: dto.blockedByPremium,
            order: dto.order,
            isCompleted: dto.completed,
            createdAt: dto.createdAt ?? Date(),
            updatedAt: dto.updatedAt ?? Date(),
            deletedAt: dto.deletedAt
        )
        self.goal = goal
    }
}


