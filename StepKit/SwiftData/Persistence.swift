//
//  Persistence.swift
//  StepKit
//
//  Created by StepKit Refactor.
//

import SwiftData

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
    
    @MainActor
    static var previewContainer: ModelContainer = {
        let controller = PersistenceController(inMemory: true)
        return controller.container
    }()
}
