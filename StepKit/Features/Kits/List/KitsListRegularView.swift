//
//  KitsListRegularView.swift
//  StepKit
//
//  Created by StepKit Refactor.
//

import SwiftUI

struct KitsListRegularView: View {
    let activeKits: [GoalEntity]
    let completedKits: [GoalEntity]
    let kitEntities: [GoalEntity]
    @Bindable var viewModel: KitsViewModel
    
    @Environment(\.syncManager) private var syncManager
    
    var body: some View {
        NavigationSplitView {
            KitsHomeView(
                activeKits: activeKits,
                completedKits: completedKits,
                viewModel: viewModel,
                isCompact: false
            )
            .navigationSplitViewColumnWidth(min: 360, ideal: 400)
        } detail: {
            NavigationStack {
                if let kitEntity = viewModel.selectedKitEntity {
                    KitDetailView(kitEntity: kitEntity)
                        .id(kitEntity.id)
                } else {
                    ContentUnavailableView(
                        "Selecciona un Kit",
                        systemImage: Symbols.kits,
                        description: Text("Elige un Kit para ver su plan y su registro")
                    )
                }
            }
        }
        .fullScreenCover(isPresented: $viewModel.showingKitCreator) {
            KitCreatorView { newKit in
                // Buscar el GoalEntity correspondiente
                if let entity = kitEntities.first(where: { $0.id == newKit.id }) {
                    viewModel.selectedKitEntity = entity
                }
            }
        }
        .sheet(isPresented: $viewModel.showingDeleteConfirmation) {
            DeleteConfirmationSheet(
                goal: viewModel.kitEntityToDelete,
                onDelete: {
                    if let kit = viewModel.kitEntityToDelete {
                        withAnimation {
                            viewModel.deleteKit(kit, syncManager: syncManager)
                        }
                    }
                    viewModel.showingDeleteConfirmation = false
                },
                onCancel: {
                    viewModel.cancelDeletion()
                }
            )
        }
        .onChange(of: kitEntities) { _, newKits in
            // Limpiar selección si el kit seleccionado ya no existe
            if let selectedId = viewModel.selectedKitId,
               !newKits.contains(where: { $0.id == selectedId }) {
                viewModel.clearSelection()
            }
        }
        .onChange(of: viewModel.selectedKitId) { _, newId in
            if let newId, let entity = kitEntities.first(where: { $0.id == newId }) {
                viewModel.selectedKitEntity = entity
            } else {
                viewModel.selectedKitEntity = nil
            }
        }
    }
}
