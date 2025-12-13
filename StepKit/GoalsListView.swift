//
//  GoalsListView.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on 13/10/25.
//

import SwiftUI
import SwiftData
import UIKit

struct GoalsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.syncManager) private var syncManager
    @Query(filter: #Predicate<GoalEntity> { !$0.isDeleted }, sort: \GoalEntity.createdAt, order: .reverse)
    private var goalEntities: [GoalEntity]

    // Query adicional de StepEntities para forzar observación de cambios en steps
    // SwiftData tiene un bug conocido donde cambios en relaciones no disparan actualizaciones
    @Query private var allSteps: [StepEntity]

    @State private var selectedGoalEntity: GoalEntity?
    @State private var selectedGoalId: UUID?
    @State private var selectedStepEntity: StepEntity?
    @State private var showingFastCreator = false
    @State private var animateEmptyState = false
    @State private var goalEntityToDelete: GoalEntity?
    @State private var showingDeleteConfirmation = false
    @State private var navigationPath: [UUID] = []

    // Colores del tema
    private let accentBlue = Color(red: 0.0, green: 0.48, blue: 1.0)
    private let accentHighlight = Color(red: 0.55, green: 0.82, blue: 1.0)

    // Checksum de steps completados para forzar re-render cuando cambia
    private var stepsCompletionChecksum: Int {
        allSteps.filter { $0.isCompleted }.count
    }

    // GoalEntities activos y completados
    private var activeGoalEntities: [GoalEntity] {
        // Acceder al checksum fuerza dependencia de allSteps
        _ = stepsCompletionChecksum
        return goalEntities.filter { !$0.isCompleted }
    }

    private var completedGoalEntities: [GoalEntity] {
        _ = stepsCompletionChecksum
        return goalEntities.filter { $0.isCompleted }
    }
    
    var body: some View {
        // Usar NavigationStack en iPhone, NavigationSplitView en iPad
        if horizontalSizeClass == .compact {
            compactLayout
        } else {
            regularLayout
        }
    }
    
    // MARK: - Compact Layout (iPhone)
    private var compactLayout: some View {
        NavigationStack(path: $navigationPath) {
            goalsListContent
                .navigationDestination(for: GoalEntity.ID.self) { goalId in
                    if let goalEntity = goalEntities.first(where: { $0.id == goalId }) {
                        GoalDetailView(goalEntity: goalEntity)
                    }
                }
        }
        .fullScreenCover(isPresented: $showingFastCreator) {
            FastCreatorView { newGoal in
                navigationPath.append(newGoal.id)
            }
        }
        .sheet(isPresented: $showingDeleteConfirmation) {
            deleteConfirmationSheet
        }
        .onChange(of: goalEntities) { _, newGoals in
            // Apple-recommended: state-driven navigation cleanup
            // Remove any IDs from path that no longer exist in goalEntities
            let validIds = Set(newGoals.map { $0.id })
            let hasInvalidIds = navigationPath.contains { !validIds.contains($0) }

            if hasInvalidIds {
                // Pop sin animación para transición suave
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    navigationPath.removeAll { !validIds.contains($0) }
                }
            }
        }
    }

    // MARK: - Regular Layout (iPad)
    private var regularLayout: some View {
        NavigationSplitView {
            goalsListContent
        } content: {
            if let goalEntity = selectedGoalEntity {
                GoalDetailView(goalEntity: goalEntity)
                    .onChange(of: selectedGoalEntity) { _, _ in
                        selectedStepEntity = nil
                    }
            } else {
                ContentUnavailableView(
                    "Selecciona un Kit",
                    systemImage: "list.bullet",
                    description: Text("Elige un kit para ver sus pasos")
                )
            }
        } detail: {
            if let stepEntity = selectedStepEntity {
                NavigationStack {
                    StepDetailView(stepEntity: stepEntity)
                        .navigationTitle(stepEntity.title)
                        .navigationBarTitleDisplayMode(.inline)
                }
            } else {
                ContentUnavailableView(
                    "Selecciona un Paso",
                    systemImage: "doc.text",
                    description: Text("Elige un paso para ver sus detalles")
                )
            }
        }
        .fullScreenCover(isPresented: $showingFastCreator) {
            FastCreatorView { newGoal in
                // Buscar el GoalEntity correspondiente
                if let entity = goalEntities.first(where: { $0.id == newGoal.id }) {
                    selectedGoalEntity = entity
                }
            }
        }
        .sheet(isPresented: $showingDeleteConfirmation) {
            deleteConfirmationSheet
        }
        .onChange(of: goalEntities) { _, newGoals in
            // Limpiar selección si el goal seleccionado ya no existe
            if let selectedId = selectedGoalId,
               !newGoals.contains(where: { $0.id == selectedId }) {
                selectedGoalEntity = nil
                selectedGoalId = nil
                selectedStepEntity = nil
            }
        }
    }

    // MARK: - Goals List Content
    @ViewBuilder
    private var goalsListContent: some View {
        if goalEntities.isEmpty {
            EmptyStateContainerView(
                animateEmptyState: $animateEmptyState,
                showingFastCreator: $showingFastCreator
            )
            .navigationBarTitleDisplayMode(.inline)
        } else {
            List(selection: horizontalSizeClass == .regular ? $selectedGoalId : nil) {
                // Kits activos
                if !activeGoalEntities.isEmpty {
                    Section {
                        ForEach(activeGoalEntities) { goalEntity in
                            goalRow(goalEntity)
                        }
                    } header: {
                        sectionHeader(title: "En progreso", icon: "target", count: activeGoalEntities.count)
                    }
                }

                // Kits completados
                if !completedGoalEntities.isEmpty {
                    Section {
                        ForEach(completedGoalEntities) { goalEntity in
                            goalRow(goalEntity)
                        }
                    } header: {
                        sectionHeader(title: "Completados", icon: "checkmark.circle", count: completedGoalEntities.count)
                    }
                }
            }
            .listStyle(.plain)
            .listRowSpacing(10)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Mis Kits")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingFastCreator = true
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                            .foregroundColor(accentBlue)
                    }
                }
            }
            .onChange(of: selectedGoalId) { _, newId in
                if let newId, let entity = goalEntities.first(where: { $0.id == newId }) {
                    selectedGoalEntity = entity
                } else {
                    selectedGoalEntity = nil
                }
            }
        }
    }
    
    // MARK: - Goal Row
    private func goalRow(_ goalEntity: GoalEntity) -> some View {
        GoalRowView(goalEntity: goalEntity)
            .contentShape(Rectangle())
            .onTapGesture {
                if horizontalSizeClass == .compact {
                    // iPhone: Push navigation con ID
                    navigationPath.append(goalEntity.id)
                } else {
                    // iPad: Selection-based con entity
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedGoalId = goalEntity.id
                    }
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button {
                    goalEntityToDelete = goalEntity
                    showingDeleteConfirmation = true
                } label: {
                    Label("Eliminar", systemImage: "trash")
                }
                .tint(.red)
            }
    }
    
    // MARK: - Section Header
    private func sectionHeader(title: String, icon: String, count: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline.weight(.medium))
                .foregroundColor(accentBlue)
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text("\(count)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
        .textCase(nil)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }
    
    // MARK: - Delete Confirmation Sheet
    private var deleteConfirmationSheet: some View {
        VStack(spacing: 24) {
            // Icono
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.1))
                    .frame(width: 72, height: 72)

                Image(systemName: "trash")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(.red)
            }
            .padding(.top, 24)

            // Texto
            VStack(spacing: 8) {
                Text("¿Eliminar este kit?")
                    .font(.title3)
                    .fontWeight(.semibold)

                if let goalEntity = goalEntityToDelete {
                    Text(goalEntity.title)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }

                Text("Esta acción no se puede deshacer")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }

            // Botones
            VStack(spacing: 12) {
                Button(role: .destructive) {
                    if let goalEntity = goalEntityToDelete {
                        withAnimation {
                            deleteGoalEntity(goalEntity)
                        }
                    }
                    showingDeleteConfirmation = false
                } label: {
                    Text("Eliminar")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                Button {
                    showingDeleteConfirmation = false
                    goalEntityToDelete = nil
                } label: {
                    Text("Cancelar")
                        .font(.body.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(.secondarySystemGroupedBackground))
                        .foregroundColor(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .presentationDetents([.height(340)])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Delete Goal
    private func deleteGoalEntity(_ entity: GoalEntity) {
        let now = Date()

        // Soft delete del goal usando el método dedicado
        entity.markAsDeleted(at: now)

        // Cascade: soft delete de todos los steps
        for step in entity.steps {
            step.deletedAt = now
            step.markModified()
        }

        // Limpiar selección si es necesario
        if selectedGoalEntity?.id == entity.id {
            selectedGoalEntity = nil
            selectedGoalId = nil
        }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        // Trigger sync después de eliminar
        syncManager?.handleDataChange()

        goalEntityToDelete = nil
    }
}

#Preview {
    GoalsListView()
        .modelContainer(for: [GoalEntity.self, StepEntity.self], inMemory: true)
}
