//
//  SyncDTO.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on 10/12/25.
//

import Foundation

// MARK: - Sync Request/Response

/// Request para sincronizar datos con el backend
struct SyncBatchRequest: Codable {
    let kits: [KitSyncDTO]
    let steps: [StepSyncDTO]
    let progressEntries: [ProgressEntrySyncDTO]
    let sessions: [WorkSessionSyncDTO]
}

/// Respuesta del servidor con el estado actual
nonisolated struct SyncBatchResponse: Codable {
    let kits: [KitSyncDTO]
    let steps: [StepSyncDTO]
    /// Opcional para tolerar un servidor anterior al registro de avance.
    let progressEntries: [ProgressEntrySyncDTO]?
    let sessions: [WorkSessionSyncDTO]?
    let conflicts: [ConflictDTO]
}

/// Información sobre conflictos detectados durante sync
struct ConflictDTO: Codable {
    let entityType: String  // "kit" | "step" | "progressEntry"
    let entityId: UUID
    let reason: String
}

// MARK: - Kit Sync DTO

/// DTO para sincronizar Kits con el backend
/// Nota: El backend Vapor usa camelCase en JSON
struct KitSyncDTO: Codable {
    let id: UUID?
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
    let createdAt: Date?
    let updatedAt: Date
    let deletedAt: Date?
    let deleted: Bool
    let resultConfirmedAt: Date?
    let steps: [StepSyncDTO]?

    // No necesita CodingKeys - Vapor usa camelCase por defecto
}

// MARK: - Step Sync DTO

/// DTO para sincronizar Steps con el backend
/// Nota: El backend Vapor usa camelCase en JSON
struct StepSyncDTO: Codable {
    let id: UUID?
    let kitId: UUID
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
    let blockedReason: String?
    let blockedAt: Date?
    var repeatEvery: String? = nil
    var repeatTimes: Int? = nil
    var completedAt: Date? = nil
    let createdAt: Date?
    let updatedAt: Date?
    let deletedAt: Date?
    /// Computed: el servidor usa deletedAt para Steps, no deleted
    var deleted: Bool {
        deletedAt != nil
    }

    private enum CodingKeys: String, CodingKey {
        case id, kitId, title, descriptionShort, descriptionLong
        case estimateMinutes, suggestedDeadline, effortLevel, adaptsTo
        case blockedByPremium, order, completed, blockedReason, blockedAt
        case repeatEvery, repeatTimes, completedAt
        case createdAt, updatedAt, deletedAt
    }
}

// MARK: - Progress Entry Sync DTO

/// Entrada del registro de avance ("progress" | "blocked").
struct ProgressEntrySyncDTO: Codable {
    let id: UUID
    let kitId: UUID
    let stepId: UUID?
    let kind: String
    let note: String
    let notedAt: Date
    let createdAt: Date?
    let updatedAt: Date
    let deletedAt: Date?

    var deleted: Bool { deletedAt != nil }
}

// MARK: - Work Session Sync DTO

struct WorkSessionSyncDTO: Codable {
    let id: UUID
    /// nil = sesión libre, sin Kit (lleva `title`).
    let kitId: UUID?
    let stepId: UUID?
    var title: String? = nil
    let startsAt: Date
    let durationMinutes: Int
    let reminderEnabled: Bool
    let createdAt: Date?
    let updatedAt: Date
    let deletedAt: Date?

    var deleted: Bool { deletedAt != nil }
}
