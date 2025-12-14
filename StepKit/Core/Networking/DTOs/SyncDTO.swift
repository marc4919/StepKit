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
}

/// Respuesta del servidor con el estado actual
struct SyncBatchResponse: Codable {
    let kits: [KitSyncDTO]
    let steps: [StepSyncDTO]
    let conflicts: [ConflictDTO]
}

/// Información sobre conflictos detectados durante sync
struct ConflictDTO: Codable {
    let entityType: String  // "kit" | "step"
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
        case blockedByPremium, order, completed, createdAt, updatedAt, deletedAt
    }
}
