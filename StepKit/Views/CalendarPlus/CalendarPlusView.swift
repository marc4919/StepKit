//
//  CalendarPlusView.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on 7/12/25.
//

import SwiftUI
import SwiftData
import UIKit
import FoundationModels
import TipKit

// MARK: - Tip
struct CreateKitFromCalendarTip: Tip {
    var title: Text {
        Text("Crear kit")
    }

    var message: Text? {
        Text("Pulsa para crear un nuevo kit con la fecha seleccionada")
    }
}

// MARK: - Navigation Wrappers
struct GoalNavigation: Hashable {
    let id: UUID
}

struct StepNavigation: Hashable {
    let id: UUID
}

struct CalendarPlusView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.syncManager) private var syncManager
    @Query(filter: #Predicate<GoalEntity> { !$0.isDeleted },
           sort: \GoalEntity.createdAt,
           order: .reverse)
    private var goalEntities: [GoalEntity]

    @State private var selectedDate: Date = Date()
    @State private var showingFastCreator = false
    @State private var navigationPath = NavigationPath()
    @State private var stepsExpanded = false

    // Tip
    private let createKitTip = CreateKitFromCalendarTip()

    // Colores del tema
    private let accentBlue = Color(red: 0.0, green: 0.48, blue: 1.0)
    private let accentHighlight = Color(red: 0.55, green: 0.82, blue: 1.0)
    private let glowColor = Color(red: 0.2, green: 0.6, blue: 1.0)

    // Kits del día seleccionado
    private var goalsForSelectedDate: [GoalEntity] {
        goalEntities.filter { entity in
            guard let dueDate = entity.dueDate else { return false }
            return Calendar.current.isDate(dueDate, inSameDayAs: selectedDate)
        }
    }

    // Steps del día seleccionado (excluye eliminados)
    private var stepsForSelectedDate: [StepEntity] {
        goalEntities.flatMap { $0.steps }
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

        for goal in goalEntities {
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

        for goal in goalEntities {
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
                        calendarSection

                        // 2. Steps del día (más accionable)
                        if !stepsForSelectedDate.isEmpty {
                            stepsSection
                                .transition(.asymmetric(
                                    insertion: .push(from: .bottom),
                                    removal: .move(edge: .top).combined(with: .opacity)
                                ))
                        }

                        // 3. Kits del día (deadlines)
                        kitsSection

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
                        fabButton
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Calendario")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: GoalNavigation.self) { nav in
                if let goalEntity = goalEntities.first(where: { $0.id == nav.id }) {
                    GoalDetailView(goalEntity: goalEntity)
                }
            }
            .navigationDestination(for: StepNavigation.self) { nav in
                if let stepEntity = goalEntities.flatMap(\.steps).first(where: { $0.id == nav.id }) {
                    let sortedSteps = stepEntity.goal?.steps.sorted { $0.order < $1.order } ?? []
                    let stepIndex = sortedSteps.firstIndex(where: { $0.id == nav.id }) ?? 0
                    StepDetailView(stepEntity: stepEntity, stepNumber: stepIndex + 1)
                } else {
                    ContentUnavailableView("Paso no encontrado", systemImage: "exclamationmark.triangle")
                }
            }
            .fullScreenCover(isPresented: $showingFastCreator) {
                FastCreatorView(
                    onKitCreated: { _ in },
                    initialDate: selectedDate
                )
            }
        }
    }

    // MARK: - Calendar Section
    private var calendarSection: some View {
        VStack(spacing: 0) {
            CalendarUIView(
                selectedDate: $selectedDate,
                stepsPerDay: stepsPerDay,
                deadlinesPerDay: deadlinesPerDay,
                accentColor: UIColor(accentBlue)
            )
            .frame(height: 450)

            // Leyenda sutil
            HStack(spacing: 16) {
                Spacer()
                HStack(spacing: 4) {
                    Circle()
                        .fill(accentHighlight)
                        .frame(width: 6, height: 6)
                    Text("Pasos")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                HStack(spacing: 4) {
                    Circle()
                        .fill(accentBlue)
                        .frame(width: 6, height: 6)
                    Text("Deadline")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Steps Section
    private var stepsSection: some View {
        let stepsToShow = stepsExpanded ? stepsForSelectedDate : Array(stepsForSelectedDate.prefix(3))

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checklist")
                    .font(.subheadline)
                    .foregroundStyle(accentBlue)

                Text("Pasos del día")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                Text("\(stepsForSelectedDate.count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(accentBlue)
                    .clipShape(Capsule())
            }

            VStack(spacing: 8) {
                ForEach(stepsToShow, id: \.id) { step in
                    swipeableStepRow(step)
                }

                if stepsForSelectedDate.count > 3 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            stepsExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(stepsExpanded ? "Ver menos" : "+ \(stepsForSelectedDate.count - 3) más")
                            Image(systemName: stepsExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption2)
                        }
                        .font(.caption)
                        .foregroundStyle(accentBlue)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Swipeable Step Row
    private func swipeableStepRow(_ step: StepEntity) -> some View {
        NavigationLink(value: StepNavigation(id: step.id)) {
            compactStepRow(step)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button {
                toggleStepCompletion(step)
            } label: {
                Label(step.isCompleted ? "Desmarcar" : "Completar", systemImage: step.isCompleted ? "arrow.uturn.backward" : "checkmark")
            }
            .tint(step.isCompleted ? .orange : .green)
        }
    }

    private func toggleStepCompletion(_ step: StepEntity) {
        withAnimation {
            step.isCompleted.toggle()
            step.markModified()  // También marca el goal parent
            UIImpactFeedbackGenerator(style: .light).impactOccurred()

            // Trigger sync después de cambio
            syncManager?.handleDataChange()
        }
    }

    // MARK: - Compact Step Row
    private func compactStepRow(_ step: StepEntity) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(step.stepTitle)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if step.estimateMinutes > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text(formatMinutes(step.estimateMinutes))
                                .font(.caption2)
                        }
                    }

                    if let kitTitle = step.goal?.title, !kitTitle.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "target")
                                .font(.caption2)
                            Text(kitTitle)
                                .font(.caption2)
                                .lineLimit(1)
                        }
                    }
                }
                .foregroundStyle(.tertiary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(Color(.tertiaryLabel))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Kits Section
    private var kitsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: "flag.fill")
                            .font(.subheadline)
                            .foregroundStyle(accentBlue)

                        Text("Deadlines")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }

                    Text(deadlineSubtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if !goalsForSelectedDate.isEmpty {
                    Text("\(goalsForSelectedDate.count)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(accentBlue)
                        .clipShape(Capsule())
                }
            }

            if goalsForSelectedDate.isEmpty {
                emptyStateForDay
            } else {
                VStack(spacing: 12) {
                    ForEach(goalsForSelectedDate) { goal in
                        kitRow(goal)
                    }
                }
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Helpers
    private var deadlineSubtitle: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(selectedDate) {
            return "Kits que finalizan hoy"
        } else if calendar.isDateInTomorrow(selectedDate) {
            return "Kits que finalizan mañana"
        } else {
            return "Kits que finalizan el \(selectedDate.formatted(.dateTime.day().month(.wide)))"
        }
    }

    private var emptyStateForDay: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 36))
                .foregroundStyle(
                    LinearGradient(
                        colors: [accentHighlight.opacity(0.6), accentBlue.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("Sin kits para este día")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("Pulsa + para crear uno")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private func kitRow(_ goal: GoalEntity) -> some View {
        let progress = goal.computedProgress

        return NavigationLink(value: GoalNavigation(id: goal.id)) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(accentBlue.opacity(0.2), lineWidth: 3)
                        .frame(width: 44, height: 44)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            LinearGradient(
                                colors: [accentHighlight, accentBlue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 44, height: 44)
                        .rotationEffect(.degrees(-90))

                    Text("\(Int(progress * 100))%")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(accentBlue)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    let pendingSteps = goal.steps.filter { !$0.isCompleted }.count
                    Text("\(pendingSteps) paso\(pendingSteps == 1 ? "" : "s") pendiente\(pendingSteps == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(.tertiaryLabel))
            }
            .padding(14)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }


    private var fabButton: some View {
        Button {
            createKitTip.invalidate(reason: .actionPerformed)
            showingFastCreator = true
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } label: {
            ZStack {
                // Fondo circular mínimo para que el glassEffect tenga forma
                Circle()
                    .fill(accentBlue.opacity(0.15))

                // Ícono blanco
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(width: 56, height: 56, alignment: .center)
            .glassEffect(.regular.tint(accentBlue).interactive(), in: Circle())
            .overlay(
                Circle()
                    .stroke(accentHighlight.opacity(0.5), lineWidth: 0.5)
            )
            .shadow(color: glowColor.opacity(0.3), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .popoverTip(createKitTip, arrowEdge: .bottom)
        .fixedSize()
    }

    private func formatMinutes(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let remaining = minutes % 60
            return remaining == 0 ? "\(hours)h" : "\(hours)h \(remaining)m"
        }
    }
}

#Preview {
    CalendarPlusView()
}
