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
    @State private var detailSize: CGSize?
    @State private var presentedOnce = false
    
    /// Sin Kits, o con el último ya saliendo: así el cambio a Mis Kits a pantalla completa se funde a la
    /// vez que el Kit se va de la lista, en una sola transición. Esperar al borrado real añadía un
    /// segundo fundido, entre dos estados vacíos iguales, con la animación de entrada repetida.
    private var showsEmptyHome: Bool {
        kitEntities.allSatisfy { viewModel.leavingKitIDs.contains($0.id) }
    }

    var body: some View {
        Group {
            if showsEmptyHome {
                // Sin Kits, una barra lateral vacía no aporta: Mis Kits ocupa toda la pantalla
                // y crear el primero está a un toque (iPad e interior del iPhone Duo).
                NavigationStack {
                    KitsHomeView(activeKits: [], completedKits: [], viewModel: viewModel)
                }
                .transition(.opacity)
            } else {
                splitView.transition(.opacity)
            }
        }
        // Al borrar el último Kit, de dos columnas a pantalla única con un fundido suave.
        .animation(.smooth(duration: 0.6), value: showsEmptyHome)
        // Un Kit deja de estar «saliendo» cuando ya no está en la lista. Quitarlo antes, con la
        // consulta aún sin reflejar el borrado, hacía reaparecer la lista un instante.
        .onChange(of: kitEntities.map(\.id), initial: true) { _, ids in
            viewModel.leavingKitIDs = viewModel.leavingKitIDs.filter { ids.contains($0) }
        }
        .sheet(isPresented: $viewModel.showingDeleteConfirmation) {
            DeleteConfirmationSheet(
                goal: viewModel.kitEntityToDelete,
                onDelete: {
                    // Primero se cierra la hoja y, ya con la lista a la vista, el Kit se va con suavidad.
                    let kit = viewModel.kitEntityToDelete
                    viewModel.showingDeleteConfirmation = false
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(300))
                        guard let kit else { return }
                        // Primero sale de la lista y, si estaba abierto, su detalle se funde;
                        // después se borra de verdad. Si era el último, las dos columnas dan paso
                        // a Mis Kits con un fundido (ver `.animation` del cuerpo).
                        withAnimation(.smooth(duration: 0.5)) {
                            _ = viewModel.leavingKitIDs.insert(kit.id)
                            if viewModel.selectedKitId == kit.id { viewModel.clearSelection() }
                        }
                        // Tras el fundido entero: borrar antes volvía a pintar la tarjeta que se iba
                        // («0 de 0 pasos») en sus últimos fotogramas, y se veía como un parpadeo.
                        try? await Task.sleep(for: .milliseconds(700))
                        withAnimation(.smooth(duration: 0.6)) {
                            viewModel.deleteKit(kit, syncManager: syncManager)
                        }
                        // Sigue «saliendo» hasta que de verdad desaparece de la lista (ver `onChange`).
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

    private var splitView: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            KitsHomeView(
                activeKits: activeKits,
                completedKits: completedKits,
                viewModel: viewModel
            )
            .navigationSplitViewColumnWidth(min: 360, ideal: 400, max: 440)
        } detail: {
            NavigationStack {
                if let kitEntity = viewModel.selectedKitEntity {
                    KitDetailView(kitEntity: kitEntity,
                                  opensResultReview: viewModel.reviewOnOpenKitID == kitEntity.id) {
                        viewModel.reviewOnOpenKitID = nil
                    }
                    .id(kitEntity.id)
                } else {
                    ContentUnavailableView {
                        Label("Selecciona un Kit", systemImage: Symbols.kits)
                    } description: {
                        Text("Elige un Kit para ver su plan y su registro")
                    } actions: {
                        // Con el detalle a pantalla completa, la lista no está a la vista: se ofrece aquí.
                        if columnVisibility == .detailOnly {
                            Button("Ver mis Kits") { withAnimation { columnVisibility = .all } }
                                .buttonStyle(.glass)
                        }
                        Button("Nuevo Kit", systemImage: "plus") { viewModel.showingKitCreator = true }
                            .buttonStyle(.glassProminent)
                    }
                }
            }
            // La columna publica su tamaño: el paso lo usa como primera estimación de su disposición.
            .onGeometryChange(for: CGSize.self) { $0.size } action: { detailSize = $0 }
            .environment(\.detailColumnSize, detailSize)
        }
        .navigationSplitViewStyle(.balanced)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
            // Por debajo de 1100 pt (iPad en vertical, iPhone Duo abierto en vertical u horizontal) el detalle
            // ocupa toda la pantalla y Mis Kits queda a un toque. Con el Duo en horizontal no caben las dos
            // columnas y la lista acababa encima del Kit, tapándolo.
            let target: NavigationSplitViewVisibility = width < 1100 ? .detailOnly : .all
            guard target != columnVisibility else { return }
            // Diferido solo la primera vez: durante su primera presentación el split vuelve a mostrar
            // la barra lateral y descarta un cambio inmediato (iOS 27.1, iPhone Duo). Después, al
            // plegar o girar, el cambio es inmediato para que no aparezca la barra un instante.
            if presentedOnce {
                columnVisibility = target
            } else {
                presentedOnce = true
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(300))
                    columnVisibility = target
                }
            }
        }
    }
}
