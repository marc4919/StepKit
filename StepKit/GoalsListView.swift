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
    @Query(filter: #Predicate<GoalEntity> { !$0.isDeleted }, sort: \GoalEntity.createdAt, order: .reverse)
    private var goalEntities: [GoalEntity]
    
    // Convertir entidades a view models
    private var goals: [Goal] {
        goalEntities.map { $0.toGoal() }
    }
    
    @State private var selectedGoal: Goal?
    @State private var selectedStep: Step?
    @State private var showingFastCreator = false
    @State private var animateEmptyState = false
    @State private var goalToDelete: Goal?
    @State private var showingDeleteConfirmation = false
    @State private var navigationPath = NavigationPath()
    
    // Colores del tema
    private let accentBlue = Color(red: 0.0, green: 0.48, blue: 1.0)
    private let accentHighlight = Color(red: 0.55, green: 0.82, blue: 1.0)
    
    // Goals activos y completados
    private var activeGoals: [Goal] {
        goals.filter { !$0.isCompleted }
    }
    
    private var completedGoals: [Goal] {
        goals.filter { $0.isCompleted }
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
                .navigationDestination(for: Goal.self) { goal in
                    GoalDetailView(goal: goal)
                }
                .navigationDestination(for: Step.self) { step in
                    StepDetailView(step: step)
                }
        }
        .fullScreenCover(isPresented: $showingFastCreator) {
            FastCreatorView { newGoal in
                navigationPath.append(newGoal)
            }
        }
        .sheet(isPresented: $showingDeleteConfirmation) {
            deleteConfirmationSheet
        }
    }
    
    // MARK: - Regular Layout (iPad)
    private var regularLayout: some View {
        NavigationSplitView {
            goalsListContent
        } content: {
            if let selectedGoal = selectedGoal {
                KitView(goal: selectedGoal, steps: selectedGoal.steps, selectedStep: $selectedStep)
                    .onChange(of: selectedGoal) { _, _ in
                        selectedStep = nil
                    }
            } else {
                ContentUnavailableView(
                    "Selecciona un Kit",
                    systemImage: "list.bullet",
                    description: Text("Elige un kit para ver sus pasos")
                )
            }
        } detail: {
            if let selectedStep = selectedStep {
                NavigationStack {
                    StepDetailView(step: selectedStep)
                        .navigationTitle(selectedStep.title)
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
                selectedGoal = newGoal
            }
        }
        .sheet(isPresented: $showingDeleteConfirmation) {
            deleteConfirmationSheet
        }
    }
    
    // MARK: - Goals List Content
    @ViewBuilder
    private var goalsListContent: some View {
        if goals.isEmpty {
            EmptyStateContainerView(
                animateEmptyState: $animateEmptyState,
                showingFastCreator: $showingFastCreator
            )
            .navigationBarTitleDisplayMode(.inline)
        } else {
            List(selection: horizontalSizeClass == .regular ? $selectedGoal : nil) {
                // Kits activos
                if !activeGoals.isEmpty {
                    Section {
                        ForEach(activeGoals) { goal in
                            goalRow(goal)
                        }
                    } header: {
                        sectionHeader(title: "En progreso", icon: "target", count: activeGoals.count)
                    }
                }
                
                // Kits completados
                if !completedGoals.isEmpty {
                    Section {
                        ForEach(completedGoals) { goal in
                            goalRow(goal)
                        }
                    } header: {
                        sectionHeader(title: "Completados", icon: "checkmark.circle", count: completedGoals.count)
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
        }
    }
    
    // MARK: - Goal Row
    private func goalRow(_ goal: Goal) -> some View {
        GoalRowView(goal: goal)
            .contentShape(Rectangle())
            .onTapGesture {
                if horizontalSizeClass == .compact {
                    // iPhone: Push navigation
                    navigationPath.append(goal)
                } else {
                    // iPad: Selection-based
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedGoal = goal
                    }
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button {
                    goalToDelete = goal
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
        .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 8, trailing: 16))
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
                
                if let goal = goalToDelete {
                    Text(goal.title)
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
                    if let goal = goalToDelete {
                        withAnimation {
                            deleteGoal(goal)
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
                    goalToDelete = nil
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
    private func deleteGoal(_ goal: Goal) {
        // Buscar la entidad correspondiente
        if let entity = goalEntities.first(where: { $0.id == goal.id }) {
            // Soft delete (marcar como eliminado)
            entity.isDeleted = true
            entity.deletedAt = Date()
            entity.updatedAt = Date()
            
            // Limpiar selección si es necesario
            if selectedGoal?.id == goal.id {
                selectedGoal = nil
            }
            
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        goalToDelete = nil
    }
}

#Preview {
    GoalsListView()
        .modelContainer(for: [GoalEntity.self, StepEntity.self], inMemory: true)
}
