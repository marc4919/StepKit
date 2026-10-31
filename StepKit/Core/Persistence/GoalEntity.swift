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
    var ownerID: String = ""
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
    /// Columna del borrado lógico. Úsala solo en `#Predicate`/`@Query`: leída desde Swift,
    /// SwiftData devuelve su propio `PersistentModel.isDeleted` (si se borró del contexto),
    /// que es `false` tras guardar. Para leer el estado usa `isRemoved`.
    var isDeleted: Bool
    var notificationsEnabled: Bool
    /// El usuario confirmó el resultado; independiente de completar todos los pasos.
    var resultConfirmedAt: Date?
    /// Fecha final que eligió la persona al crear el Kit (o que aceptó del asistente).
    /// Nil en Kits anteriores a guardarla: entonces se usa el último paso.
    var targetDate: Date?

    @Relationship(deleteRule: .cascade, inverse: \StepEntity.goal)
    var steps: [StepEntity] = []
    
    init(
        id: UUID = UUID(),
        ownerID: String = "",
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
        isDeleted: Bool = false,
        notificationsEnabled: Bool = true
    ) {
        self.id = id
        self.ownerID = ownerID
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
        self.deletedAt = deletedAt ?? (isDeleted ? updatedAt : nil)
        self.isDeleted = isDeleted
        self.notificationsEnabled = notificationsEnabled
    }
    
    // MARK: - Conversion from KitDTO
    
    convenience init(from dto: KitDTO, ownerID: String) {
        self.init(
            id: dto.id ?? UUID(),
            ownerID: ownerID,
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
        targetDate ?? steps.compactMap { $0.suggestedDeadline }.max()
    }

    // MARK: - Modification Tracking

    /// Marca la entidad como modificada localmente (actualiza timestamp y versión).
    /// Nunca retrocede el reloj LWW si el estado remoto observado estaba adelantado.
    func markModified(at date: Date = Date()) {
        updatedAt = max(date, updatedAt.addingTimeInterval(0.001))
        version += 1
    }

    /// Borrado lógico, leído de forma fiable: siempre que se marca `isDeleted` se fija `deletedAt`.
    var isRemoved: Bool { deletedAt != nil }

    /// Marca la entidad como eliminada (soft delete)
    func markAsDeleted(at date: Date = Date()) {
        let deletionDate = max(date, updatedAt.addingTimeInterval(0.001))
        isDeleted = true
        deletedAt = deletionDate
        updatedAt = deletionDate
        version += 1
    }

    // MARK: - Sync Conversion

    /// Convierte la entidad a DTO para sincronización
    func toSyncDTO() -> KitSyncDTO {
        KitSyncDTO(
            id: id,
            title: planTitle,
            kpi: kpi,
            horizonDays: horizonDays,
            metaType: metaType,
            metaTags: metaTags,
            risks: risks,
            version: version,
            progress: computedProgress,
            sourceModel: sourceModel,
            promptVersion: nil,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            deleted: isRemoved,
            resultConfirmedAt: resultConfirmedAt,
            targetDate: targetDate,
            steps: nil  // Steps se envían por separado
        )
    }

    /// Actualiza la entidad desde un DTO del servidor
    func update(from dto: KitSyncDTO) {
        planTitle = dto.title
        kpi = dto.kpi
        horizonDays = dto.horizonDays
        metaType = dto.metaType
        metaTags = dto.metaTags
        risks = dto.risks
        version = dto.version
        progress = dto.progress ?? computedProgress
        sourceModel = dto.sourceModel
        createdAt = dto.createdAt ?? createdAt
        updatedAt = dto.updatedAt
        deletedAt = dto.deletedAt ?? (dto.deleted ? dto.updatedAt : nil)
        isDeleted = dto.deleted
        resultConfirmedAt = dto.resultConfirmedAt
        // Un servidor que aún no guarda la fecha no la envía: se conserva la local.
        if let targetDate = dto.targetDate { self.targetDate = targetDate }
    }

    /// Crea una entidad desde un DTO de sync
    convenience init(fromSync dto: KitSyncDTO, ownerID: String) {
        self.init(
            id: dto.id ?? UUID(),
            ownerID: ownerID,
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
        self.resultConfirmedAt = dto.resultConfirmedAt
        self.targetDate = dto.targetDate
    }
}
