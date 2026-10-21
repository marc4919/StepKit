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
        case information
        case annotations

        var id: String { rawValue }
    }

    @Bindable var kitEntity: GoalEntity
    @Environment(\.modelContext) private var modelContext
    @Environment(\.syncManager) private var syncManager
    @State private var presentedSheet: PresentedSheet?
    @State private var segment = 0
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var editingEntry: ProgressEntryEntity?
    @Query(sort: \ProgressEntryEntity.notedAt, order: .reverse) private var allEntries: [ProgressEntryEntity]

    private var kitEntries: [ProgressEntryEntity] {
        allEntries.filter { $0.kitID == kitEntity.id && $0.ownerID == kitEntity.ownerID && $0.deletedAt == nil }
    }

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                    .id("kit.top")
                if allStepsDone {
                    resultCard
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.9, anchor: .top))
                                .animation(.spring(response: 0.55, dampingFraction: 0.75).delay(0.45)),
                            removal: .opacity))
                }
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
        .onChange(of: allStepsDone) { _, done in
            guard done else { return }
            // Al completar el último paso: subir arriba y que aparezca el resultado.
            withAnimation(.smooth(duration: 0.5)) { proxy.scrollTo("kit.top", anchor: .top) }
        }
        }
        .background(alignment: .top) { BrandGlow() }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(kitEntity.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Asistente primero, como en el paso; a su derecha, detalles (con «Editar» dentro).
            ToolbarItemGroup(placement: .topBarTrailing) {
                NavigationLink {
                    KitAssistantHubView(kit: kitEntity)
                } label: {
                    Label("Asistente", systemImage: Symbols.assistant)
                }
                .badge(hasPendingProposal ? 1 : 0)
                .accessibilityIdentifier("kit.assistant")
                .accessibilityValue(hasPendingProposal ? "Propuesta pendiente" : "")
                Button("Detalles del Kit", systemImage: "info.circle") { presentedSheet = .information }
                    .accessibilityIdentifier("kit.info")
                    .accessibilityHint("Muestra los detalles del Kit y permite editarlos")
            }
        }
        .onAppear {
            ProgressLog.importLegacyKitNotes(for: kitEntity, context: modelContext)
        }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .information:
                KitInfoSheetView(goalEntity: kitEntity)
            case .annotations:
                KitNoteSheet(kit: kitEntity)
            }
        }
        .sheet(item: $editingEntry) { entry in
            let step = kitEntity.orderedActiveSteps.first { $0.id == entry.stepID }
            EditProgressEntrySheet(entry: entry,
                                   stepLabel: step.map { "\(kitEntity.position(of: $0)) · \($0.stepTitle)" })
        }
    }

    private var header: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14))
            : AnyLayout(HStackLayout(spacing: 18))
        return layout {
            ProgressRing(done: kitEntity.completedStepCount, total: kitEntity.activeStepCount, size: 92)
            VStack(alignment: .leading, spacing: 6) {
                Text(kitEntity.title)
                    .font(.title2.bold())
                    .fixedSize(horizontal: false, vertical: true)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 6) { headerChips }
                    VStack(alignment: .leading, spacing: 6) { headerChips }
                }
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

    private var allStepsDone: Bool {
        kitEntity.activeStepCount > 0 && kitEntity.completedStepCount == kitEntity.activeStepCount
    }

    /// Con todos los pasos hechos, el resultado se revisa aquí mismo, sin salir del Kit.
    private var resultCard: some View {
        let confirmed = kitEntity.resultConfirmedAt != nil
        return NavigationLink {
            ResultReviewView(kit: kitEntity)
        } label: {
            HStack(spacing: 12) {
                IconChip(symbol: confirmed ? "checkmark.seal.fill" : "flag.checkered",
                         color: MetaTint.done, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(confirmed ? "Resultado confirmado" : "Has completado todos los pasos")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(confirmed ? "Ver el resumen de tu recorrido" : "Revisa si tienes lo que buscabas")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(MetaTint.done.opacity(0.12), in: .rect(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(MetaTint.done.opacity(0.25)))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("kit.reviewResult")
    }

    private var hasPendingProposal: Bool {
        KitAssistantStore.shared.conversations(for: kitEntity.id)
            .contains { $0.proposals.contains { $0.state == .pending } }
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
                        PlanStepRow(step: step, number: index + 1,
                                    state: step.progressState(hasEntries: kitEntries.contains { $0.stepID == step.id })) {
                            withAnimation(.snappy) {
                                try? ProgressLog.toggleCompletion(of: step, context: modelContext)
                            }
                            syncManager?.handleDataChange()
                        }
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

    @ViewBuilder private var meta: some View {
        Label("\(step.estimateMinutes) min", systemImage: Symbols.time)
            .foregroundStyle(MetaTint.time)
        if let date = step.suggestedDeadline {
            Label(date.formatted(.dateTime.day().month(.abbreviated)), systemImage: Symbols.calendar)
                .foregroundStyle(MetaTint.date)
        }
        if let repetition = step.repetition {
            Label(repetition.label, systemImage: "repeat")
                .foregroundStyle(MetaTint.repeatTint)
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

    let onToggle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Como en Recordatorios: el círculo completa el paso sin entrar en él.
            Button(action: onToggle) {
                Image(systemName: state.symbol)
                    .font(.title3)
                    .foregroundStyle(state.tint)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .padding(.leading, 4)
            .padding(.top, 2)
            .sensoryFeedback(.success, trigger: step.isCompleted) { _, done in done }
            .accessibilityLabel(step.isCompleted ? "Marcar como pendiente" : "Marcar como completado")
            .accessibilityValue("Paso \(number): \(step.stepTitle)")
            .accessibilityIdentifier("step.rowToggle")
            NavigationLink {
                StepDetailView(stepEntity: step, stepNumber: number)
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(step.stepTitle)
                            .foregroundStyle(state == .done ? .secondary : .primary)
                            .strikethrough(state == .done, color: .secondary)
                            .multilineTextAlignment(.leading)
                        FlowLayout(spacing: 10) { meta }
                            .font(.caption.weight(.medium))
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                .padding(.vertical, 12)
                .padding(.trailing, 12)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Paso \(number): \(step.stepTitle). \(state.label)")
            .accessibilityHint("Toca dos veces para abrir los detalles del paso")
            .accessibilityIdentifier("step.row")
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
