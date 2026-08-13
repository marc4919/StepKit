//
//  CalendarPlusView.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on 7/12/25.
//

import SwiftUI
import SwiftData
import FoundationModels

struct CalendarPlusView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.syncManager) private var syncManager
    @Environment(AuthManager.self) private var authManager
    @Query(filter: #Predicate<GoalEntity> { !$0.isDeleted },
           sort: \GoalEntity.createdAt,
           order: .reverse)
    private var goalEntities: [GoalEntity]

    @State private var selectedDate: Date = Date()
    @State private var showingKitCreator = false
    @State private var navigationPath = NavigationPath()
    @State private var stepsExpanded = false

    // Tip
    private let createKitTip = CreateKitFromCalendarTip()

    private var visibleGoalEntities: [GoalEntity] {
        guard let ownerID = authManager.currentUser?.id else { return [] }
        return goalEntities.filter { $0.ownerID == ownerID }
    }


    // Kits del día seleccionado
    private var goalsForSelectedDate: [GoalEntity] {
        visibleGoalEntities.filter { entity in
            guard let dueDate = entity.dueDate else { return false }
            return Calendar.current.isDate(dueDate, inSameDayAs: selectedDate)
        }
    }

    // Steps del día seleccionado (excluye eliminados)
    private var stepsForSelectedDate: [StepEntity] {
        visibleGoalEntities.flatMap { $0.steps }
            .filter { step in
                guard step.deletedAt == nil else { return false }  // Excluir eliminados
                guard let deadline = step.suggestedDeadline else { return false }
                return Calendar.current.isDate(deadline, inSameDayAs: selectedDate)
            }
            .sorted { $0.order < $1.order }
    }

    // Steps agrupados por día (para decoraciones, excluye eliminados)
    private var stepsPerDay: [DateComponents: Int] {
        var result: [DateComponents: Int] = [:]
        let calendar = Calendar.current

        for goal in visibleGoalEntities {
            for step in goal.steps {
                guard step.deletedAt == nil else { continue }  // Excluir eliminados
                guard let deadline = step.suggestedDeadline else { continue }
                let components = calendar.dateComponents([.year, .month, .day], from: deadline)
                result[components, default: 0] += 1
            }
        }
        return result
    }

    // Deadlines de kits agrupados por día
    private var deadlinesPerDay: [DateComponents: Int] {
        var result: [DateComponents: Int] = [:]
        let calendar = Calendar.current

        for goal in visibleGoalEntities {
            guard let dueDate = goal.dueDate else { continue }
            let components = calendar.dateComponents([.year, .month, .day], from: dueDate)
            result[components, default: 0] += 1
        }
        return result
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                ScrollView {
                    VStack(spacing: 20) {
                        // 1. Calendario con indicadores
                        CalendarSectionView(
                            selectedDate: $selectedDate,
                            stepsPerDay: stepsPerDay,
                            deadlinesPerDay: deadlinesPerDay
                        )

                        // 2. Steps del día (más accionable)
                        if !stepsForSelectedDate.isEmpty {
                            CalendarStepsSectionView(
                                steps: stepsForSelectedDate,
                                stepsExpanded: $stepsExpanded,
                                onToggleStep: toggleStepCompletion
                            )
                            .transition(.asymmetric(
                                insertion: .push(from: .bottom),
                                removal: .move(edge: .top).combined(with: .opacity)
                            ))
                        }

                        // 3. Kits del día (deadlines)
                        CalendarKitsSectionView(
                            goals: goalsForSelectedDate,
                            selectedDate: selectedDate
                        )

                        // 4. Insight del día (AI) - solo si hay contenido
                        if !stepsForSelectedDate.isEmpty || !goalsForSelectedDate.isEmpty {
                            DayInsightView(
                                selectedDate: selectedDate,
                                steps: stepsForSelectedDate,
                                goals: goalsForSelectedDate
                            )
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .animation(.easeInOut(duration: 0.3), value: stepsForSelectedDate.isEmpty)
                    .animation(.easeInOut(duration: 0.3), value: goalsForSelectedDate.isEmpty)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }
                .background(Color(.systemGroupedBackground))

                // FAB
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        CalendarFABButton(tip: createKitTip) {
                            showingKitCreator = true
                        }
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Calendario")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: GoalNavigation.self) { nav in
                if let goalEntity = visibleGoalEntities.first(where: { $0.id == nav.id }) {
                    KitDetailView(kitEntity: goalEntity)
                }
            }
            .navigationDestination(for: StepNavigation.self) { nav in
                if let stepEntity = visibleGoalEntities.flatMap(\.steps).first(where: { $0.id == nav.id }) {
                    let sortedSteps = stepEntity.goal?.steps.sorted { $0.order < $1.order } ?? []
                    let stepIndex = sortedSteps.firstIndex(where: { $0.id == nav.id }) ?? 0
                    StepDetailView(stepEntity: stepEntity, stepNumber: stepIndex + 1)
                } else {
                    ContentUnavailableView("Paso no encontrado", systemImage: "exclamationmark.triangle")
                }
            }
            .fullScreenCover(isPresented: $showingKitCreator) {
                KitCreatorView(
                    onKitCreated: { _ in },
                    initialDate: selectedDate
                )
            }
        }
    }

    // MARK: - Actions
    private func toggleStepCompletion(_ step: StepEntity) {
        withAnimation {
            step.isCompleted.toggle()
            step.markModified()  // También marca el goal parent
            UIImpactFeedbackGenerator(style: .light).impactOccurred()

            // Trigger sync después de cambio
            syncManager?.handleDataChange()
        }
    }
}

#Preview {
    CalendarPlusView()
}
