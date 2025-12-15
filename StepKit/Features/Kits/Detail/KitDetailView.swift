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

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header con icono y título
                KitDetailHeaderView(kitEntity: kitEntity)

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
                        .foregroundStyle(Color.accentColor)
                }
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel("Añadir anotación")
                .accessibilityHint("Abre la vista para añadir anotaciones al kit")

                Button {
                    showingExtendedInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(Color.accentColor)
                }
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel("Información del kit")
                .accessibilityHint("Muestra información detallada del kit")
            }
        }
        .sheet(isPresented: $showingExtendedInfo) {
            KitInfoSheetView(goalEntity: kitEntity)
        }
        .sheet(isPresented: $showingAnnotations) {
            KitAnnotationsView(goal: kitEntity.toGoal())
        }
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
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)

                Text("Pasos")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Text("\(kitEntity.steps.count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
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
                    ForEach(sortedSteps.enumerated(), id: \.element.id) { index, stepEntity in
                        NavigationLink {
                            StepDetailView(stepEntity: stepEntity, stepNumber: index + 1)
                        } label: {
                            StepRowView(stepEntity: stepEntity, index: index + 1, isLast: index == sortedSteps.count - 1)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(.isButton)
                        .accessibilityLabel("Paso \(index + 1) de \(sortedSteps.count): \(stepEntity.stepTitle)")
                        .accessibilityHint("Toca dos veces para abrir los detalles del paso")
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
                .accessibilityHidden(true)
            
            Text("No hay pasos definidos")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
