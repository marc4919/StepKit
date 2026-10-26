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
    @Environment(AuthManager.self) private var authManager
    
    // Animado: al borrar un Kit, el resto de la lista se recoloca con suavidad.
    @Query(filter: #Predicate<GoalEntity> { !$0.isDeleted }, sort: \GoalEntity.createdAt, order: .reverse,
           animation: .smooth(duration: 0.45))
    private var kitEntities: [GoalEntity]

    // Query adicional de StepEntities para forzar observación de cambios en steps
    // SwiftData tiene un bug conocido donde cambios en relaciones no disparan actualizaciones
    @Query private var allSteps: [StepEntity]
    
    @State private var viewModel = KitsViewModel()

    // MARK: - Computed Properties

    private var currentOwnerID: String? { authManager.currentUser?.id }

    private var visibleKitEntities: [GoalEntity] {
        guard let currentOwnerID else { return [] }
        // También en memoria: @Query puede tardar en reflejar un borrado recién hecho.
        return kitEntities.filter { $0.ownerID == currentOwnerID && !$0.isDeleted }
    }
    
    // Checksum de steps completados para forzar re-render cuando cambia
    private var stepsCompletionChecksum: Int {
        guard let currentOwnerID else { return 0 }
        return allSteps.filter { $0.ownerID == currentOwnerID && $0.isCompleted }.count
    }

    // GoalEntities activos y completados
    private var activeKitEntities: [GoalEntity] {
        // Acceder al checksum fuerza dependencia de allSteps
        _ = stepsCompletionChecksum
        return visibleKitEntities.filter { !$0.isCompleted }
    }

    private var completedKitEntities: [GoalEntity] {
        _ = stepsCompletionChecksum
        return visibleKitEntities.filter { $0.isCompleted }
    }
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                KitsListCompactView(
                    activeKits: activeKitEntities,
                    completedKits: completedKitEntities,
                    kitEntities: visibleKitEntities,
                    viewModel: viewModel
                )
            } else {
                KitsListRegularView(
                    activeKits: activeKitEntities,
                    completedKits: completedKitEntities,
                    kitEntities: visibleKitEntities,
                    viewModel: viewModel
                )
            }
        }
        // iPhone Duo al plegar o desplegar: se pasa de una columna a dos (o al revés).
        // El Kit abierto se conserva en lugar de volver a Mis Kits.
        .onChange(of: horizontalSizeClass) { _, sizeClass in
            if sizeClass == .compact {
                if let id = viewModel.selectedKitId, viewModel.navigationPath.isEmpty {
                    viewModel.navigationPath = [id]
                }
            } else if let id = viewModel.navigationPath.last,
                      let kit = visibleKitEntities.first(where: { $0.id == id }) {
                viewModel.selectKit(kit)
                viewModel.navigationPath = []
            }
        }
    }
}

#Preview {
    KitsListView()
        .modelContainer(for: [GoalEntity.self, StepEntity.self], inMemory: true)
}
