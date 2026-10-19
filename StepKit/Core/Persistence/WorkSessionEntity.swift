//
//  WorkSessionEntity.swift
//  StepKit
//
//  Sesión reservada (v4.4, DP1: solo dentro de StepKit). Reservar tiempo no
//  completa el paso. Se sincroniza con /sync/batch.
//

import Foundation
import SwiftData

@Model
final class WorkSessionEntity {
    @Attribute(.unique) var id: UUID
    var ownerID: String = ""
    var kitID: UUID
    var stepID: UUID?
    var startsAt: Date
    var durationMinutes: Int
    var reminderEnabled: Bool
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    var endsAt: Date { startsAt.addingTimeInterval(TimeInterval(durationMinutes * 60)) }

    init(
        id: UUID = UUID(),
        ownerID: String,
        kitID: UUID,
        stepID: UUID?,
        startsAt: Date,
        durationMinutes: Int,
        reminderEnabled: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.ownerID = ownerID
        self.kitID = kitID
        self.stepID = stepID
        self.startsAt = startsAt
        self.durationMinutes = durationMinutes
        self.reminderEnabled = reminderEnabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }

    func markModified(at date: Date = Date()) {
        updatedAt = max(date, updatedAt.addingTimeInterval(0.001))
    }

    func markAsDeleted(at date: Date = Date()) {
        markModified(at: date)
        deletedAt = updatedAt
    }

    // MARK: - Sync

    func toSyncDTO() -> WorkSessionSyncDTO {
        WorkSessionSyncDTO(
            id: id, kitId: kitID, stepId: stepID, startsAt: startsAt, durationMinutes: durationMinutes,
            reminderEnabled: reminderEnabled, createdAt: createdAt, updatedAt: updatedAt, deletedAt: deletedAt
        )
    }

    func update(from dto: WorkSessionSyncDTO) {
        startsAt = dto.startsAt
        durationMinutes = dto.durationMinutes
        reminderEnabled = dto.reminderEnabled
        createdAt = dto.createdAt ?? createdAt
        updatedAt = dto.updatedAt
        deletedAt = dto.deletedAt
    }

    convenience init(fromSync dto: WorkSessionSyncDTO, ownerID: String) {
        self.init(
            id: dto.id, ownerID: ownerID, kitID: dto.kitId, stepID: dto.stepId, startsAt: dto.startsAt,
            durationMinutes: dto.durationMinutes, reminderEnabled: dto.reminderEnabled,
            createdAt: dto.createdAt ?? Date(), updatedAt: dto.updatedAt, deletedAt: dto.deletedAt
        )
    }
}
