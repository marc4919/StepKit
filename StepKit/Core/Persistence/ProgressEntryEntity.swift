//
//  ProgressEntryEntity.swift
//  StepKit
//
//  Registro de avance (v4.4): avances parciales y bloqueos de un Kit, normalmente
//  ligados a un paso. Se sincroniza con /sync/batch como Kits y Pasos.
//

import Foundation
import SwiftData

@Model
final class ProgressEntryEntity {
    enum Kind: String, CaseIterable {
        case progress
        case blocked
        /// Una sesión hecha de un paso que se repite (notedAt = día de la sesión).
        case session
    }

    @Attribute(.unique) var id: UUID
    var ownerID: String = ""
    var kitID: UUID
    var stepID: UUID?
    var kindRaw: String
    var note: String
    /// Momento del avance. Editar la nota no lo cambia.
    var notedAt: Date
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    var kind: Kind { Kind(rawValue: kindRaw) ?? .progress }

    init(
        id: UUID = UUID(),
        ownerID: String,
        kitID: UUID,
        stepID: UUID?,
        kind: Kind,
        note: String,
        notedAt: Date = Date(),
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.ownerID = ownerID
        self.kitID = kitID
        self.stepID = stepID
        self.kindRaw = kind.rawValue
        self.note = note
        self.notedAt = notedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }

    /// Mismo reloj monotónico que Kit y Paso: nunca retrocede.
    func markModified(at date: Date = Date()) {
        updatedAt = max(date, updatedAt.addingTimeInterval(0.001))
    }

    func markAsDeleted(at date: Date = Date()) {
        markModified(at: date)
        deletedAt = updatedAt
    }

    // MARK: - Sync

    func toSyncDTO() -> ProgressEntrySyncDTO {
        ProgressEntrySyncDTO(
            id: id, kitId: kitID, stepId: stepID, kind: kindRaw, note: note,
            notedAt: notedAt, createdAt: createdAt, updatedAt: updatedAt, deletedAt: deletedAt
        )
    }

    func update(from dto: ProgressEntrySyncDTO) {
        kindRaw = dto.kind
        note = dto.note
        notedAt = dto.notedAt
        createdAt = dto.createdAt ?? createdAt
        updatedAt = dto.updatedAt
        deletedAt = dto.deletedAt
    }

    convenience init(fromSync dto: ProgressEntrySyncDTO, ownerID: String) {
        self.init(
            id: dto.id, ownerID: ownerID, kitID: dto.kitId, stepID: dto.stepId,
            kind: Kind(rawValue: dto.kind) ?? .progress, note: dto.note, notedAt: dto.notedAt,
            createdAt: dto.createdAt ?? Date(), updatedAt: dto.updatedAt, deletedAt: dto.deletedAt
        )
    }
}
