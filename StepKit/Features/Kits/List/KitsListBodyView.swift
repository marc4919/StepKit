//
//  KitsListBodyView.swift
//  StepKit
//
//  Created by StepKit Refactor.
//

import SwiftUI

struct KitsListBodyView: View {
    let activeKits: [GoalEntity]
    let completedKits: [GoalEntity]
    @Bindable var viewModel: KitsViewModel
    let isCompact: Bool
    
    var body: some View {
        Group {
            if activeKits.isEmpty && completedKits.isEmpty {
                EmptyStateContainerView(
                    animateEmptyState: $viewModel.animateEmptyState,
                    showingKitCreator: $viewModel.showingKitCreator
                )
                .navigationBarTitleDisplayMode(.inline)
            } else {
                List(selection: isCompact ? nil : $viewModel.selectedKitId) {
                    // Kits activos
                    if !activeKits.isEmpty {
                        Section {
                            ForEach(activeKits) { kitEntity in
                                kitRow(kitEntity)
                            }
                        } header: {
                            SectionHeaderView(title: "En progreso", icon: "target", count: activeKits.count)
                        }
                    }
                    
                    // Kits completados
                    if !completedKits.isEmpty {
                        Section {
                            ForEach(completedKits) { kitEntity in
                                kitRow(kitEntity)
                            }
                        } header: {
                            SectionHeaderView(title: "Completados", icon: "checkmark.circle", count: completedKits.count)
                        }
                    }
                }
                .listStyle(.plain)
                .listRowSpacing(10)
                .scrollContentBackground(.hidden)
                .background(Color.appBackground)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("Mis Kits")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            viewModel.showingKitCreator = true
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        } label: {
                            Image(systemName: "plus")
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.accentColor)
                        }
                        .accessibilityIdentifier("kit.create")
                        .accessibilityLabel("Crear kit")
                        .accessibilityHint("Abre el creador de kits")
                    }
                }
            }
        }
    }
    
    private func kitRow(_ kitEntity: GoalEntity) -> some View {
        KitRowView(kitEntity: kitEntity)
            .contentShape(Rectangle())
            .onTapGesture {
                if isCompact {
                    // iPhone: Push navigation con ID
                    viewModel.navigationPath.append(kitEntity.id)
                } else {
                    // iPad: Selection-based con entity
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.selectKit(kitEntity)
                    }
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("kit.row")
            .accessibilityLabel("Kit: \(kitEntity.title)")
            .accessibilityValue("Progreso: \(Int(kitEntity.progress * 100))%, KPI: \(kitEntity.kpi)")
            .accessibilityHint(isCompact ? "Toca dos veces para ver los detalles del kit" : "Toca dos veces para seleccionar este kit")
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button {
                    viewModel.prepareForDeletion(kitEntity)
                } label: {
                    Label("Eliminar", systemImage: "trash")
                }
                .tint(.red)
            }
    }
}
