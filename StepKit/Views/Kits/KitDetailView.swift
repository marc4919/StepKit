//
//  KitDetailView.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on 13/10/25.
//
//  Refactored by StepKit Refactor.
//

import SwiftUI
import SwiftData

struct KitDetailView: View {
    @Bindable var kitEntity: GoalEntity
    @State private var showingExtendedInfo = false
    @State private var showingAnnotations = false
    @State private var displayedProgress: Double
    @State private var displayedPercentage: Int
    @State private var shouldAnimateOnReturn = false

    init(kitEntity: GoalEntity) {
        self.kitEntity = kitEntity
        let progress = kitEntity.computedProgress
        _displayedProgress = State(initialValue: progress)
        _displayedPercentage = State(initialValue: Int(progress * 100))
    }


    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header con icono y título
                headerSection

                // Sección de pasos
                stepsSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Kit")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    showingAnnotations = true
                } label: {
                    Image(systemName: "note.text.badge.plus")
                        .foregroundColor(.accentColor)
                }

                Button {
                    showingExtendedInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundColor(.accentColor)
                }
            }
        }
        .sheet(isPresented: $showingExtendedInfo) {
            ExtendedKitInfoView(goalEntity: kitEntity)
        }
        .sheet(isPresented: $showingAnnotations) {
            KitAnnotationsView(goal: kitEntity.toGoal())
        }
        .onAppear {
            let currentProgress = kitEntity.computedProgress

            // Solo animar si volvemos de StepDetailView con cambios
            if shouldAnimateOnReturn && displayedProgress != currentProgress {
                withAnimation(.easeInOut(duration: 0.7)) {
                    displayedProgress = currentProgress
                    displayedPercentage = Int(currentProgress * 100)
                }
            }
            shouldAnimateOnReturn = false
        }
        .onDisappear {
            // Marcar que al volver debemos verificar si hay cambios
            shouldAnimateOnReturn = true
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Icono con progreso
            ZStack {
                // Glow exterior
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                kitEntity.isCompleted ? Color.green.opacity(0.2) : Color.accentHighlight.opacity(0.2),
                                kitEntity.isCompleted ? Color.green.opacity(0.05) : Color.accentColor.opacity(0.05),
                                .clear
                            ],
                            center: .center,
                            startRadius: 30,
                            endRadius: 60
                        )
                    )
                    .frame(width: 100, height: 100)

                // Progreso circular
                Circle()
                    .stroke(
                        kitEntity.isCompleted ? Color.green.opacity(0.15) : Color.accentColor.opacity(0.15),
                        lineWidth: 6
                    )
                    .frame(width: 72, height: 72)

                Circle()
                    .trim(from: 0, to: displayedProgress)
                    .stroke(
                        kitEntity.isCompleted
                            ? LinearGradient.completedGradient
                            : LinearGradient.accentGradient,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 72, height: 72)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.7), value: displayedProgress)

                // Contenido central
                if kitEntity.isCompleted {
                    Image(systemName: "checkmark")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.green)
                } else {
                    Text("\(displayedPercentage)%")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.accentColor)
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.7), value: displayedPercentage)
                }
            }

            // Título y KPI
            VStack(spacing: 8) {
                Text(kitEntity.planTitle)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)

                Text(kitEntity.kpi)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 16)

            // Contador de pasos
            HStack(spacing: 6) {
                Image(systemName: "list.bullet")
                    .font(.caption)
                    .foregroundColor(.accentColor)

                Text("\(kitEntity.steps.filter { $0.isCompleted }.count) de \(kitEntity.steps.count) pasos completados")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.accentColor.opacity(0.1))
            .clipShape(Capsule())
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    // Steps ordenados por order
    private var sortedSteps: [StepEntity] {
        kitEntity.steps.sorted { $0.order < $1.order }
    }

    // MARK: - Steps Section
    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header de sección
            HStack(spacing: 8) {
                Image(systemName: "list.bullet")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.accentColor)

                Text("Pasos")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                Text("\(kitEntity.steps.count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(Capsule())
            }

            if kitEntity.steps.isEmpty {
                // Estado vacío
                emptyStepsView
            } else {
                // Lista de pasos
                VStack(spacing: 0) {
                    ForEach(Array(sortedSteps.enumerated()), id: \.element.id) { index, stepEntity in
                        NavigationLink {
                            StepDetailView(stepEntity: stepEntity, stepNumber: index + 1)
                        } label: {
                            stepRow(stepEntity, index: index + 1, isLast: index == sortedSteps.count - 1)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }
    
    // MARK: - Empty Steps View
    private var emptyStepsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 36))
                .foregroundStyle(LinearGradient.accentWithOpacity( 0.6))
            
            Text("No hay pasos definidos")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    // MARK: - Step Row
    private func stepRow(_ stepEntity: StepEntity, index: Int, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                // Indicador de paso
                ZStack {
                    Circle()
                        .fill(stepEntity.isCompleted ? Color.green.opacity(0.1) : Color.accentColor.opacity(0.1))
                        .frame(width: 44, height: 44)

                    if stepEntity.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.green)
                    } else {
                        Text("\(index)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.accentColor)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(stepEntity.stepTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    Text(stepEntity.descriptionShort)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)

                    // Tiempo estimado y fecha
                    HStack(spacing: 8) {
                        if stepEntity.estimateMinutes > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                Text(formatMinutes(stepEntity.estimateMinutes))
                            }
                        }
                        if let deadline = stepEntity.suggestedDeadline {
                            if stepEntity.estimateMinutes > 0 {
                                Text("•")
                            }
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                Text(deadline, format: .dateTime.day().month(.abbreviated))
                            }
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(.tertiaryLabel))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            if !isLast {
                Divider()
                    .padding(.leading, 74)
            }
        }
    }
    
    // MARK: - Helpers
    private func formatMinutes(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "\(hours) h"
            } else {
                return "\(hours)h \(remainingMinutes)min"
            }
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: GoalEntity.self, StepEntity.self, configurations: config)
    let kitEntity = GoalEntity(
        planTitle: "Aprender SwiftUI",
        horizonDays: 42,
        kpi: "Completar 5 proyectos funcionales",
        metaType: "learning",
        metaTags: ["technical", "desk"],
        risks: ["Falta de tiempo", "Curva de aprendizaje"]
    )
    container.mainContext.insert(kitEntity)

    return NavigationStack {
        KitDetailView(kitEntity: kitEntity)
    }
    .modelContainer(container)
}
