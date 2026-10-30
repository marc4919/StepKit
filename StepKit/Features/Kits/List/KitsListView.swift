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
        // Una sola vista dividida en todos los tamaños. En ancho compacto (iPhone, Duo cerrado) el
        // sistema la colapsa a una pila por sí mismo y conserva el Kit y el paso abiertos al plegar
        // o girar. Antes se cambiaba a otro árbol con su propia ruta y el relevo en mitad del plegado
        // dejaba la barra del Kit a medio montar (cápsula vacía abajo, botones perdidos).
        KitsListRegularView(
            activeKits: activeKitEntities,
            completedKits: completedKitEntities,
            kitEntities: visibleKitEntities,
            viewModel: viewModel
        )
        .fullScreenCover(isPresented: $viewModel.showingKitCreator) {
            KitCreatorView { newKit in
                if let entity = visibleKitEntities.first(where: { $0.id == newKit.id }) {
                    viewModel.selectKit(entity)
                }
            }
        }
    }
}

#Preview {
    KitsListView()
        .modelContainer(for: [GoalEntity.self, StepEntity.self], inMemory: true)
}
