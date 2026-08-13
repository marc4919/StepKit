//
//  Persistence.swift
//  StepKit
//
//  Created by StepKit Refactor.
//

import SwiftData
import Foundation

struct PersistenceController {
    static let shared = PersistenceController()

    let container: ModelContainer

    init(inMemory: Bool = false) {
        let schema = Schema([
            GoalEntity.self,
            StepEntity.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)

        do {
            container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
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
        for step in legacySteps {
            step.ownerID = ownerID
        }

        if !legacyGoals.isEmpty || !legacySteps.isEmpty {
            try context.save()
        }
    }
    
    @MainActor
    static var previewContainer: ModelContainer = {
        let controller = PersistenceController(inMemory: true)
        return controller.container
    }()
}
