//
//  SearchView.swift
//  StepKit
//
//  Created by StepKit Refactor.
//

import SwiftUI
import SwiftData

struct SearchView: View {
    @Query(filter: #Predicate<GoalEntity> { !$0.isDeleted }, sort: \GoalEntity.createdAt, order: .reverse)
    private var goalEntities: [GoalEntity]

    @Query(filter: #Predicate<StepEntity> { $0.goal?.isDeleted == false || $0.goal == nil }, sort: \StepEntity.order)
    private var stepEntities: [StepEntity]

    @State private var searchText: String = ""
    @State private var navigationPath = NavigationPath()
    
    // MARK: - Computed Properties
    
    private var goals: [Goal] {
        goalEntities.map { $0.toGoal() }
    }
    
    private var steps: [Step] {
        stepEntities
            .filter { step in
                guard let goal = step.goal else { return false }
                return !goal.isDeleted
            }
            .map { $0.toStep() }
    }
    
    private var filteredGoals: [Goal] {
        guard !searchText.isEmpty else { return [] }
        let query = searchText.lowercased()
        return goals.filter { goal in
            goal.planTitle.lowercased().contains(query)
        }
    }

    private var filteredSteps: [Step] {
        guard !searchText.isEmpty else { return [] }
        let query = searchText.lowercased()
        return steps.filter { step in
            step.stepTitle.lowercased().contains(query)
        }
    }
    
    private var hasResults: Bool {
        !filteredGoals.isEmpty || !filteredSteps.isEmpty
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if searchText.isEmpty {
                    SearchEmptyStateView()
                } else if !hasResults {
                    SearchNoResultsView(searchText: searchText)
                } else {
                    resultsList
                }
            }
            .navigationTitle("Búsqueda")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Buscar kits y pasos...")
            .navigationDestination(for: GoalEntity.ID.self) { kitId in
                if let kitEntity = goalEntities.first(where: { $0.id == kitId }) {
                    KitDetailView(kitEntity: kitEntity)
                }
            }
            .navigationDestination(for: StepEntity.ID.self) { stepId in
                if let stepEntity = stepEntities.first(where: { $0.id == stepId }) {
                    let sortedSteps = stepEntity.goal?.steps.sorted { $0.order < $1.order } ?? []
                    let stepIndex = sortedSteps.firstIndex(where: { $0.id == stepId }) ?? 0
                    StepDetailView(stepEntity: stepEntity, stepNumber: stepIndex + 1)
                }
            }
        }
    }
    
    // MARK: - Results List
    private var resultsList: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Sección de Kits
                if !filteredGoals.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeaderView(title: "Kits", icon: "target", count: filteredGoals.count)

                        VStack(spacing: 10) {
                            ForEach(filteredGoals) { goal in
                                SearchKitRow(kit: goal) {
                                    navigationPath.append(goal.id)
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }
                            }
                        }
                    }
                }

                // Sección de Pasos
                if !filteredSteps.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeaderView(title: "Pasos", icon: "list.bullet", count: filteredSteps.count)

                        VStack(spacing: 10) {
                            ForEach(filteredSteps) { step in
                                SearchStepRow(step: step) {
                                    navigationPath.append(step.id)
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(Color.appBackground)
    }
}
