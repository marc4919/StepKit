//
//  Persistence.swift
//  StepKit
//
//  Created by StepKit Refactor.
//

import SwiftData
import Foundation

/// Esquema de TestFlight hasta la build 5, congelado: copia exacta de las propiedades guardadas
/// entonces. No se toca nunca; sirve para reconocer los almacenes antiguos y migrarlos.
enum StepKitSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [GoalEntity.self, StepEntity.self, ProgressEntryEntity.self, WorkSessionEntity.self]
    }

    @Model final class GoalEntity {
        @Attribute(.unique) var id: UUID = UUID()
        var ownerID: String = ""
        var planTitle: String = ""
        var horizonDays: Int = 0
        var kpi: String = ""
        var metaType: String = ""
        var metaTags: [String] = []
        var risks: [String] = []
        var version: Int = 1
        var progress: Double = 0
        var sourceModel: String?
        var createdAt: Date = Date()
        var updatedAt: Date = Date()
        var deletedAt: Date?
        var isDeleted: Bool = false
        var notificationsEnabled: Bool = true
        var resultConfirmedAt: Date?
        @Relationship(deleteRule: .cascade, inverse: \StepEntity.goal)
        var steps: [StepEntity] = []
        init() {}
    }

    @Model final class StepEntity {
        @Attribute(.unique) var id: UUID = UUID()
        var ownerID: String = ""
        var stepTitle: String = ""
        var descriptionShort: String = ""
        var descriptionLong: String = ""
        var estimateMinutes: Int = 0
        var suggestedDeadline: Date?
        var effortLevel: String = ""
        var adaptsTo: String = ""
        var blockedByPremium: Bool = false
        var order: Int = 0
        var isCompleted: Bool = false
        var createdAt: Date = Date()
        var updatedAt: Date = Date()
        var deletedAt: Date?
        var notificationEnabled: Bool = true
        var blockedReason: String?
        var blockedAt: Date?
        var completedAt: Date?
        var repeatEvery: String?
        var repeatTimes: Int?
        var goal: GoalEntity?
        init() {}
    }

    @Model final class ProgressEntryEntity {
        @Attribute(.unique) var id: UUID = UUID()
        var ownerID: String = ""
        var kitID: UUID = UUID()
        var stepID: UUID?
        var kindRaw: String = ""
        var note: String = ""
        var notedAt: Date = Date()
        var createdAt: Date = Date()
        var updatedAt: Date = Date()
        var deletedAt: Date?
        init() {}
    }

    @Model final class WorkSessionEntity {
        @Attribute(.unique) var id: UUID = UUID()
        var ownerID: String = ""
        var kitID: UUID = UUID()
        var stepID: UUID?
        var startsAt: Date = Date()
        var durationMinutes: Int = 0
        var reminderEnabled: Bool = false
        var createdAt: Date = Date()
        var updatedAt: Date = Date()
        var deletedAt: Date?
        var isFree: Bool = false
        var title: String?
        init() {}
    }
}

/// Esquema actual. V2 añade la fecha final del Kit (`GoalEntity.targetDate`).
/// Cada cambio de modelo futuro: copiar este esquema congelado como V(n) y añadir su etapa.
enum StepKitSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] {
        [GoalEntity.self, StepEntity.self, ProgressEntryEntity.self, WorkSessionEntity.self]
    }
}

enum StepKitMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [StepKitSchemaV1.self, StepKitSchemaV2.self] }
    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: StepKitSchemaV1.self, toVersion: StepKitSchemaV2.self)]
    }
}

struct PersistenceController {
    static let shared = PersistenceController()

    let container: ModelContainer

    /// `storeURL` solo lo usan los tests; la app abre el almacén por defecto.
    init(inMemory: Bool = false, storeURL: URL? = nil) {
        let schema = Schema(versionedSchema: StepKitSchemaV2.self)
        let modelConfiguration = storeURL.map { ModelConfiguration(schema: schema, url: $0) }
            ?? ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)

        do {
            container = try ModelContainer(for: schema,
                                           migrationPlan: StepKitMigrationPlan.self,
                                           configurations: [modelConfiguration])
        } catch {
            // Puede aparecer en un crash report de Release: conservar solo el
            // modo técnico, nunca el error subyacente ni rutas del sandbox.
            fatalError("Could not create StepKit ModelContainer; inMemory=\(inMemory)")
        }
    }

    /// Asocia registros anteriores a la introducción de ownership con una sesión
    /// que el servidor acaba de revalidar. Nunca se invoca para un login nuevo.
    @MainActor
    func claimLegacyData(for ownerID: String) throws {
        guard !ownerID.isEmpty else { return }

        let context = container.mainContext
        let legacyGoals = try context.fetch(
            FetchDescriptor<GoalEntity>(predicate: #Predicate { $0.ownerID == "" })
        )
        let legacySteps = try context.fetch(
            FetchDescriptor<StepEntity>(predicate: #Predicate { $0.ownerID == "" })
        )

        for goal in legacyGoals {
            goal.ownerID = ownerID
        }
        let claimableSteps = legacySteps.filter { step in
            step.goal == nil || step.goal?.ownerID == ownerID
        }
        for step in claimableSteps {
            step.ownerID = ownerID
        }

        guard !legacyGoals.isEmpty || !claimableSteps.isEmpty else { return }

        do {
            try context.save()
        } catch {
            // Mantener la operación reintentable si SwiftData no pudo confirmar
            // la transacción. El marcador de Keychain tampoco se eliminará.
            for goal in legacyGoals {
                goal.ownerID = ""
            }
            for step in claimableSteps {
                step.ownerID = ""
            }
            throw error
        }
    }

    @MainActor
    func hasUnownedLegacyData() throws -> Bool {
        let context = container.mainContext
        let legacyGoals = try context.fetch(
            FetchDescriptor<GoalEntity>(predicate: #Predicate { $0.ownerID == "" })
        )
        if !legacyGoals.isEmpty {
            return true
        }

        let legacySteps = try context.fetch(
            FetchDescriptor<StepEntity>(predicate: #Predicate { $0.ownerID == "" })
        )
        return legacySteps.contains { step in
            step.goal == nil || step.goal?.ownerID.isEmpty == true
        }
    }

    #if DEBUG
    @MainActor
    func resetLocalDataForE2E() throws {
        try deleteAllLocalData()
    }
    #endif

    /// Borra todos los Kits, pasos, avances y sesiones del dispositivo (borrado de cuenta y reset E2E).
    @MainActor
    func deleteAllLocalData() throws {
        let context = container.mainContext
        let steps = try context.fetch(FetchDescriptor<StepEntity>())
        let goals = try context.fetch(FetchDescriptor<GoalEntity>())
        let entries = try context.fetch(FetchDescriptor<ProgressEntryEntity>())

        for entry in entries {
            context.delete(entry)
        }
        for session in try context.fetch(FetchDescriptor<WorkSessionEntity>()) {
            context.delete(session)
        }

        for step in steps {
            context.delete(step)
        }
        for goal in goals {
            context.delete(goal)
        }

        try context.save()
    }
    
    @MainActor
    static var previewContainer: ModelContainer = {
        let controller = PersistenceController(inMemory: true)
        return controller.container
    }()
}

extension PersistenceController: LegacyDataClaiming {}
