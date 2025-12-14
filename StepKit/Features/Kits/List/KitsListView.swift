//
//  KitsListView.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on 13/10/25.
//  Refactored by StepKit Refactor.
//

import SwiftUI
import SwiftData

struct KitsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    @Query(filter: #Predicate<GoalEntity> { !$0.isDeleted }, sort: \GoalEntity.createdAt, order: .reverse)
    private var kitEntities: [GoalEntity]

    // Query adicional de StepEntities para forzar observación de cambios en steps
    // SwiftData tiene un bug conocido donde cambios en relaciones no disparan actualizaciones
    @Query private var allSteps: [StepEntity]
    
    @State private var viewModel = KitsViewModel()

    // MARK: - Computed Properties
    
    // Checksum de steps completados para forzar re-render cuando cambia
    private var stepsCompletionChecksum: Int {
        allSteps.filter { $0.isCompleted }.count
    }

    // GoalEntities activos y completados
    private var activeKitEntities: [GoalEntity] {
        // Acceder al checksum fuerza dependencia de allSteps
        _ = stepsCompletionChecksum
        return kitEntities.filter { !$0.isCompleted }
    }

    private var completedKitEntities: [GoalEntity] {
        _ = stepsCompletionChecksum
        return kitEntities.filter { $0.isCompleted }
    }
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                KitsListCompactView(
                    activeKits: activeKitEntities,
                    completedKits: completedKitEntities,
                    kitEntities: kitEntities,
                    viewModel: viewModel
                )
            } else {
                KitsListRegularView(
                    activeKits: activeKitEntities,
                    completedKits: completedKitEntities,
                    kitEntities: kitEntities,
                    viewModel: viewModel
                )
            }
        }
    }
}

#Preview {
    KitsListView()
        .modelContainer(for: [GoalEntity.self, StepEntity.self], inMemory: true)
}
