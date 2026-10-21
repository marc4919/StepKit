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
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            KitsHomeView(
                activeKits: activeKits,
                completedKits: completedKits,
                viewModel: viewModel,
                isCompact: false
            )
            .navigationSplitViewColumnWidth(min: 360, ideal: 400, max: 440)
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
        .navigationSplitViewStyle(.balanced)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
            // En vertical (iPad o interior del iPhone Duo) el detalle ocupa toda la pantalla
            // y Mis Kits queda a un toque con el botón de barra lateral.
            let target: NavigationSplitViewVisibility = width < 900 ? .detailOnly : .all
            // Diferido: durante su primera presentación el split vuelve a mostrar la barra
            // lateral y descarta un cambio inmediato (observado en iOS 27.1, iPhone Duo).
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                columnVisibility = target
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
                    // Primero se cierra la hoja y, ya con la lista a la vista, el Kit se va con suavidad.
                    let kit = viewModel.kitEntityToDelete
                    viewModel.showingDeleteConfirmation = false
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(350))
                        guard let kit else { return }
                        withAnimation(.smooth(duration: 0.45)) {
                            viewModel.deleteKit(kit, syncManager: syncManager)
                        }
                    }
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
