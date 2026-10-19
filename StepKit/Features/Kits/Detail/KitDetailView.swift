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
    private enum PresentedSheet: String, Identifiable {
        case edit
        case information
        case annotations

        var id: String { rawValue }
    }

    @Bindable var kitEntity: GoalEntity
    @State private var presentedSheet: PresentedSheet?
    @State private var segment = 0
    @State private var editingEntry: ProgressEntryEntity?
    @Query(sort: \ProgressEntryEntity.notedAt, order: .reverse) private var allEntries: [ProgressEntryEntity]

    private var kitEntries: [ProgressEntryEntity] {
        allEntries.filter { $0.kitID == kitEntity.id && $0.ownerID == kitEntity.ownerID && $0.deletedAt == nil }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                Picker("Vista", selection: $segment) {
                    Text("Plan").tag(0)
                    Text("Registro").tag(1)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("kit.segment")
                if segment == 0 {
                    stepsSection
                } else {
                    KitLogView(kit: kitEntity, entries: kitEntries,
                               onEdit: { editingEntry = $0 },
                               onAddNote: { presentedSheet = .annotations })
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 30)
        }
        .background(alignment: .top) { BrandGlow() }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(kitEntity.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Editar Kit", systemImage: "pencil") { presentedSheet = .edit }
                    .accessibilityIdentifier("kit.edit")
                    .accessibilityHint("Permite cambiar el título y el indicador de éxito del Kit")
                Button("Información", systemImage: "info.circle") { presentedSheet = .information }
                    .accessibilityHint("Muestra información detallada del kit")
            }
        }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .edit:
                KitEditSheetView(kitEntity: kitEntity)
            case .information:
                KitInfoSheetView(goalEntity: kitEntity)
            case .annotations:
                KitAnnotationsView(goal: kitEntity.toGoal())
            }
        }
        .sheet(item: $editingEntry) { entry in
            let step = kitEntity.orderedActiveSteps.first { $0.id == entry.stepID }
            EditProgressEntrySheet(entry: entry,
                                   stepLabel: step.map { "\(kitEntity.position(of: $0)) · \($0.stepTitle)" })
        }
    }

    private var header: some View {
        HStack(spacing: 18) {
            ProgressRing(done: kitEntity.completedStepCount, total: kitEntity.activeStepCount, size: 92)
            VStack(alignment: .leading, spacing: 6) {
                Text(kitEntity.title)
                    .font(.title2.bold())
                    .fixedSize(horizontal: false, vertical: true)
                if !kitEntity.kpi.isEmpty {
                    Text(kitEntity.kpi).foregroundStyle(.secondary)
                }
                HStack(spacing: 6) { headerChips }
            }
        }
        .padding(.top, 4)
    }

    @ViewBuilder private var headerChips: some View {
        MetaChip(symbol: "checkmark.circle",
                 text: "\(kitEntity.completedStepCount) de \(kitEntity.activeStepCount)",
                 color: MetaTint.done)
        if let date = kitEntity.dueDate {
            MetaChip(symbol: Symbols.wantedDate, text: date.formatted(.dateTime.day().month(.abbreviated)),
                     color: MetaTint.date)
        }
    }

    // MARK: - Plan

    private var stepsSection: some View {
        Group {
            if kitEntity.orderedActiveSteps.isEmpty {
                emptyStepsView
            } else {
                VStack(spacing: 0) {
                    let steps = kitEntity.orderedActiveSteps
                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                        NavigationLink {
                            StepDetailView(stepEntity: step, stepNumber: index + 1)
                        } label: {
                            PlanStepRow(step: step, number: index + 1,
                                        state: step.progressState(hasEntries: kitEntries.contains { $0.stepID == step.id }))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("step.row")
                        .accessibilityHint("Toca dos veces para abrir los detalles del paso")
                        if index < steps.count - 1 {
                            Divider().padding(.leading, 52)
                        }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18))
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
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18))
    }
}

// MARK: - Fila del plan

private struct PlanStepRow: View {
    let step: StepEntity
    let number: Int
    let state: StepProgressState

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: state.symbol)
                .font(.title3)
                .foregroundStyle(state.tint)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(step.stepTitle)
                    .foregroundStyle(state == .done ? .secondary : .primary)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 10) {
                    Label("\(step.estimateMinutes) min", systemImage: Symbols.time)
                        .foregroundStyle(MetaTint.time)
                    if let date = step.suggestedDeadline {
                        Label(date.formatted(.dateTime.day().month(.abbreviated)), systemImage: Symbols.calendar)
                            .foregroundStyle(MetaTint.date)
                    }
                    if state == .inProgress || state == .blocked {
                        Text(state.label)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(state == .blocked ? .red : .orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background((state == .blocked ? Color.red : .orange).opacity(0.14), in: .capsule)
                    }
                }
                .font(.caption.weight(.medium))
                .lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(12)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Paso \(number): \(step.stepTitle). \(state.label)")
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
