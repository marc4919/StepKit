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
            KitsListBodyView(
                activeKits: activeKits,
                completedKits: completedKits,
                viewModel: viewModel,
                isCompact: true
            )
            .navigationDestination(for: GoalEntity.ID.self) { kitId in
                if let kitEntity = kitEntities.first(where: { $0.id == kitId }) {
                    KitDetailView(kitEntity: kitEntity)
                }
            }
        }
        .fullScreenCover(isPresented: $viewModel.showingKitCreator) {
            KitCreatorView { newKit in
                viewModel.navigationPath.append(newKit.id)
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
