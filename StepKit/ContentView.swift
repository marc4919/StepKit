//
//  ContentView.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on 6/10/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Kits", systemImage: "target"){
                GoalsListView()
            }
            Tab("Calendario", systemImage: "calendar.badge.clock"){
                CalendarPlusView()
            }
            Tab("Asistente", systemImage: "sparkles"){
                TrainerView()
            }
            Tab("Perfil", systemImage: "person.circle"){
                ProfileView()
            }
            Tab(role: .search){
                SearchView()
            }
        }
    }
}

struct SearchView: View {
    @Query(filter: #Predicate<GoalEntity> { !$0.isDeleted }, sort: \GoalEntity.createdAt, order: .reverse)
    private var goalEntities: [GoalEntity]

    @Query(filter: #Predicate<StepEntity> { $0.goal?.isDeleted == false || $0.goal == nil }, sort: \StepEntity.order)
    private var stepEntities: [StepEntity]

    @State private var searchText: String = ""
    @State private var navigationPath = NavigationPath()

    // Colores del tema (consistente con otras vistas)
    private let accentBlue = Color(red: 0.0, green: 0.48, blue: 1.0)
    private let accentHighlight = Color(red: 0.55, green: 0.82, blue: 1.0)
    
    // Convertir entidades a view models
    private var goals: [Goal] {
        goalEntities.map { $0.toGoal() }
    }
    
    private var steps: [Step] {
        // Filtrar pasos que pertenecen a goals no eliminados
        stepEntities
            .filter { step in
                guard let goal = step.goal else { return false }
                return !goal.isDeleted
            }
            .map { $0.toStep() }
    }
    
    // Resultados de búsqueda (solo por título)
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
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if searchText.isEmpty {
                    emptySearchState
                } else if !hasResults {
                    noResultsState
                } else {
                    resultsList
                }
            }
            .navigationTitle("Búsqueda")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Buscar kits y pasos...")
            .navigationDestination(for: GoalEntity.ID.self) { goalId in
                if let goalEntity = goalEntities.first(where: { $0.id == goalId }) {
                    GoalDetailView(goalEntity: goalEntity)
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
    
    // MARK: - Empty Search State
    private var emptySearchState: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icono con glow
            ZStack {
                // Glow de fondo
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [accentBlue.opacity(0.2), .clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)

                // Círculo con icono
                Circle()
                    .fill(accentBlue.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "magnifyingglass")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [accentHighlight, accentBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            // Texto
            VStack(spacing: 8) {
                Text("Encuentra tus kits y pasos")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text("Escribe en el buscador para empezar")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 40)
    }
    
    // MARK: - No Results State
    private var noResultsState: some View {
        ContentUnavailableView.search(text: searchText)
    }
    
    // MARK: - Results List
    private var resultsList: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Sección de Kits
                if !filteredGoals.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader(title: "Kits", icon: "target", count: filteredGoals.count)

                        VStack(spacing: 10) {
                            ForEach(filteredGoals) { goal in
                                goalResultRow(goal)
                            }
                        }
                    }
                }

                // Sección de Pasos
                if !filteredSteps.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader(title: "Pasos", icon: "list.bullet", count: filteredSteps.count)

                        VStack(spacing: 10) {
                            ForEach(filteredSteps) { step in
                                stepResultRow(step)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Section Header
    private func sectionHeader(title: String, icon: String, count: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline.weight(.medium))
                .foregroundColor(accentBlue)

            Text(title)
                .font(.headline)
                .foregroundColor(.primary)

            Spacer()

            Text("\(count)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(accentBlue.opacity(0.1))
                .clipShape(Capsule())
        }
    }
    
    // MARK: - Goal Result Row
    private func goalResultRow(_ goal: Goal) -> some View {
        Button {
            navigationPath.append(goal.id)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 14) {
                // Icono circular
                ZStack {
                    Circle()
                        .fill(accentBlue.opacity(0.1))
                        .frame(width: 44, height: 44)

                    Image(systemName: "target")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(accentBlue)
                }

                // Contenido
                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.planTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    Text(goal.kpi)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(.tertiaryLabel))
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Step Result Row
    private func stepResultRow(_ step: Step) -> some View {
        Button {
            navigationPath.append(step.id)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 14) {
                // Icono circular
                ZStack {
                    Circle()
                        .fill(accentBlue.opacity(0.1))
                        .frame(width: 44, height: 44)

                    Image(systemName: "list.bullet")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(accentBlue)
                }

                // Contenido
                VStack(alignment: .leading, spacing: 4) {
                    Text(step.stepTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    Text(step.description.short)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)

                    // Tiempo estimado
                    if step.estimateMinutes > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text(formatMinutes(step.estimateMinutes))
                                .font(.caption)
                        }
                        .foregroundStyle(.tertiary)
                        .padding(.top, 2)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(.tertiaryLabel))
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Helpers
    private func formatMinutes(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "\(hours)h"
            } else {
                return "\(hours)h \(remainingMinutes)m"
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [GoalEntity.self, StepEntity.self], inMemory: true)
}
