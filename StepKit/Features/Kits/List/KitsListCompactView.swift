//
//  KitsListCompactView.swift
//  StepKit
//
//  Created by StepKit Refactor.
//

import SwiftUI

struct KitsListCompactView: View {
    let activeKits: [GoalEntity]
    let completedKits: [GoalEntity]
    let kitEntities: [GoalEntity]
    @Bindable var viewModel: KitsViewModel
    
    @Environment(\.syncManager) private var syncManager
    
    var body: some View {
        NavigationStack(path: $viewModel.navigationPath) {
            KitsHomeView(
                activeKits: activeKits,
                completedKits: completedKits,
                viewModel: viewModel
            )
            .navigationDestination(for: GoalEntity.ID.self) { kitId in
                if let kitEntity = kitEntities.first(where: { $0.id == kitId }) {
                    KitDetailView(kitEntity: kitEntity,
                                  opensResultReview: viewModel.reviewOnOpenKitID == kitId) {
                        viewModel.reviewOnOpenKitID = nil
                    }
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
                        try? await Task.sleep(for: .milliseconds(300))
                        guard let kit else { return }
                        // Primero sale de la lista con suavidad; después se borra de verdad.
                        withAnimation(.smooth(duration: 0.5)) {
                            _ = viewModel.leavingKitIDs.insert(kit.id)
                        }
                        try? await Task.sleep(for: .milliseconds(550))
                        viewModel.deleteKit(kit, syncManager: syncManager)
                        viewModel.leavingKitIDs.remove(kit.id)
                    }
                },
                onCancel: {
                    viewModel.cancelDeletion()
                }
            )
        }
        .onChange(of: kitEntities) { _, newKits in
            // Clean up navigation path if kits are deleted externally
            let validIds = Set(newKits.map { $0.id })
            let hasInvalidIds = viewModel.navigationPath.contains { !validIds.contains($0) }

            if hasInvalidIds {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    viewModel.navigationPath.removeAll { !validIds.contains($0) }
                }
            }
        }
    }
}
