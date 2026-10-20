//
//  KitsHomeView.swift
//  StepKit
//
//  Mis Kits v4.4 (iPhone): tarjeta Continuar con el Kit que avanzaste por última vez,
//  otros Kits en curso y Kits terminados.
//

import SwiftUI
import SwiftData

struct KitsHomeView: View {
    let activeKits: [GoalEntity]
    let completedKits: [GoalEntity]
    @Bindable var viewModel: KitsViewModel
    /// iPhone: abre el Kit en la pila. iPad: lo selecciona en la columna de detalle.
    var isCompact = true
    @Query(sort: \ProgressEntryEntity.notedAt, order: .reverse) private var allEntries: [ProgressEntryEntity]
    @State private var reviewingKit: GoalEntity?
    @State private var continuingStep: StepEntity?

    /// Todos los pasos terminados pero el resultado aún sin confirmar.
    private var pendingResultKits: [GoalEntity] {
        completedKits.filter { $0.resultConfirmedAt == nil }.sorted { $0.lastActivity > $1.lastActivity }
    }

    private var confirmedKits: [GoalEntity] {
        completedKits.filter { $0.resultConfirmedAt != nil }
    }

    /// Última nota de avance del Kit (no bloqueos, no vacías).
    private func lastProgress(of kit: GoalEntity) -> ProgressEntryEntity? {
        allEntries.first {
            $0.kitID == kit.id && $0.ownerID == kit.ownerID && $0.deletedAt == nil
                && $0.kind == .progress && !$0.note.isEmpty
        }
    }

    /// Kit que se avanzó por última vez: el cambio más reciente en el Kit o en sus pasos.
    private var continueKit: GoalEntity? {
        activeKits.max { $0.lastActivity < $1.lastActivity }
    }

    private var otherKits: [GoalEntity] {
        activeKits
            .filter { $0.id != continueKit?.id }
            .sorted { $0.lastActivity > $1.lastActivity }
    }

    var body: some View {
        Group {
            if activeKits.isEmpty && completedKits.isEmpty {
                KitsEmptyView { openCreator() }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        ForEach(pendingResultKits) { kit in
                            PendingResultCard(kit: kit) {
                                reviewingKit = kit
                            } onBackToPlan: {
                                open(kit)
                            }
                        }
                        if let kit = continueKit {
                            ContinueCard(kit: kit, lastProgress: lastProgress(of: kit)) {
                                if let step = kit.nextStep {
                                    continuingStep = step
                                } else {
                                    open(kit)
                                }
                            } onOpenKit: {
                                open(kit)
                            }
                        }
                        if !otherKits.isEmpty {
                            section(title: activeKits.count > 1 && continueKit != nil ? "Otros Kits en curso" : "En curso",
                                    kits: otherKits)
                        }
                        if !confirmedKits.isEmpty {
                            section(title: "Terminados", kits: confirmedKits)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 30)
                }
                .background(alignment: .top) { BrandGlow() }
                .background(Color(.systemGroupedBackground))
            }
        }
        .navigationTitle("Mis Kits")
        .onAppear {
            // iPad: el detalle empieza mostrando el Kit que avanzaste por última vez.
            if !isCompact, viewModel.selectedKitEntity == nil, let kit = continueKit {
                viewModel.selectKit(kit)
            }
        }
        .navigationDestination(item: $continuingStep) { step in
            StepDetailView(stepEntity: step, stepNumber: step.goal?.position(of: step) ?? 1)
        }
        .navigationDestination(item: $reviewingKit) { kit in
            ResultReviewView(kit: kit) {
                reviewingKit = nil
                open(kit)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Crear Kit", systemImage: "plus") { openCreator() }
                    .accessibilityIdentifier("kit.create")
                    .accessibilityHint("Abre el creador de kits")
            }
        }
    }

    private func section(title: String, kits: [GoalEntity]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3.bold())
                .padding(.horizontal, 4)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                ForEach(Array(kits.enumerated()), id: \.element.id) { index, kit in
                    Button { open(kit) } label: { KitHomeRow(kit: kit, lastProgress: lastProgress(of: kit)) }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("kit.row")
                        .contextMenu {
                            Button("Eliminar Kit", systemImage: "trash", role: .destructive) {
                                viewModel.prepareForDeletion(kit)
                            }
                        }
                    if index < kits.count - 1 {
                        Divider().padding(.leading, 72)
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 22))
        }
    }

    private func open(_ kit: GoalEntity) {
        if isCompact {
            viewModel.navigationPath.append(kit.id)
        } else {
            viewModel.selectKit(kit)
        }
    }

    private func openCreator() {
        viewModel.showingKitCreator = true
    }
}

// MARK: - Tarjeta Continuar

private struct ContinueCard: View {
    let kit: GoalEntity
    let lastProgress: ProgressEntryEntity?
    let onContinue: () -> Void
    let onOpenKit: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button(action: onOpenKit) { header.contentShape(.rect) }
                .buttonStyle(.plain)
                .accessibilityHint("Abre el plan del Kit")
                .accessibilityIdentifier("kit.row")
            if lastProgress != nil || kit.nextStep != nil {
                Divider().padding(.top, 6)
            }
            if let entry = lastProgress {
                HStack(alignment: .top, spacing: 12) {
                    IconChip(symbol: Symbols.note, color: .accentColor, size: 30)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Dónde lo dejaste").font(.headline)
                        Text(entry.note).foregroundStyle(.secondary)
                        Label("Último avance · \(entry.notedAt.formatted(.dateTime.day().month(.abbreviated)))",
                              systemImage: Symbols.calendar)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
            }
            if let step = kit.nextStep {
                nextStep(step)
            } else {
                Button(action: onOpenKit) {
                    Label("Abrir Kit", systemImage: "chevron.right")
                        .labelStyle(TrailingIconLabelStyle())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 26))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("kit.continueCard")
    }

    private var header: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 24))
            : AnyLayout(HStackLayout(alignment: .top))
        return layout {
            VStack(alignment: .leading, spacing: 6) {
                (Text("CONTINUAR").font(.caption2.weight(.bold)).foregroundStyle(.tint)
                 + Text("  · último que avanzaste").font(.caption2).foregroundStyle(.secondary))
                Text(kit.title)
                    .font(.title.bold())
                    .fixedSize(horizontal: false, vertical: true)
                if let date = kit.dueDate {
                    Label("Fecha deseada · \(date.formatted(.dateTime.day().month(.abbreviated)))",
                          systemImage: Symbols.wantedDate)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            if typeSize.isAccessibilitySize {
                HStack(spacing: 12) {
                    ProgressRing(done: kit.completedStepCount, total: kit.activeStepCount, size: 64)
                    stepCount.font(.body)
                }
            } else {
                VStack(spacing: 4) {
                    ProgressRing(done: kit.completedStepCount, total: kit.activeStepCount, size: 78)
                    stepCount.font(.caption2)
                }
            }
        }
    }

    private var stepCount: some View {
        Text("\(kit.completedStepCount) de \(kit.activeStepCount) pasos")
            .foregroundStyle(.secondary)
    }

    private func nextStep(_ step: StepEntity) -> some View {
        TintCard(strength: 0.10) {
            HStack(alignment: .top, spacing: 12) {
                NextMark().padding(.top, 2)
                VStack(alignment: .leading, spacing: 4) {
                    Eyebrow(text: "Paso \(kit.position(of: step)) · \(step.estimateMinutes) min")
                    Text(step.title)
                        .font(.title3.bold())
                        .fixedSize(horizontal: false, vertical: true)
                    if !step.descriptionShort.isEmpty {
                        Text(step.descriptionShort)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                }
            }
            Button(action: onContinue) {
                Label("Continuar", systemImage: "chevron.right")
                    .labelStyle(TrailingIconLabelStyle())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("kit.continue")
            .accessibilityHint("Abre el siguiente paso de \(kit.title)")
        }
    }
}

// MARK: - Pasos terminados, resultado por confirmar

private struct PendingResultCard: View {
    let kit: GoalEntity
    @Environment(\.dynamicTypeSize) private var typeSize
    let onReview: () -> Void
    let onBackToPlan: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow(text: "Pasos terminados · falta revisar el resultado", color: .orange)
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                : AnyLayout(HStackLayout(spacing: 14))
            layout {
                ProgressRing(done: kit.completedStepCount, total: kit.activeStepCount, size: 70)
                VStack(alignment: .leading, spacing: 4) {
                    Text(kit.title).font(.title2.bold())
                    Text("\(kit.completedStepCount) de \(kit.activeStepCount) pasos terminados")
                        .foregroundStyle(.secondary)
                    Text("Resultado sin confirmar")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }
            TintCard(tint: .orange, strength: 0.12) {
                HStack(alignment: .top, spacing: 12) {
                    IconChip(symbol: "clock.badge.questionmark", color: .orange)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Resultado por confirmar").font(.headline)
                        Text("Has completado los pasos. Comprueba que tienes lo que buscabas antes de confirmar el resultado.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Button(action: onReview) {
                    Label("Revisar resultado", systemImage: "chevron.right")
                        .labelStyle(TrailingIconLabelStyle())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("result.review")
                Button(action: onBackToPlan) {
                    Text("Volver al plan").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 26))
    }
}

// MARK: - Fila de Kit

private struct KitHomeRow: View {
    let kit: GoalEntity
    let lastProgress: ProgressEntryEntity?

    var body: some View {
        HStack(spacing: 14) {
            ProgressRing(done: kit.completedStepCount, total: kit.activeStepCount, size: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text(kit.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                if kit.isCompleted {
                    Label("\(kit.activeStepCount) de \(kit.activeStepCount) pasos", systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if let next = kit.nextStep {
                    Text(next.title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if !kit.isCompleted {
                    HStack(spacing: 8) {
                        if let date = kit.dueDate {
                            Label(date.formatted(.dateTime.day().month(.abbreviated)), systemImage: Symbols.wantedDate)
                                .foregroundStyle(MetaTint.date)
                        }
                        if let entry = lastProgress {
                            Label(entry.notedAt.formatted(.dateTime.day().month(.abbreviated)), systemImage: Symbols.note)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.caption.weight(.medium))
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(14)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Estado vacío

struct KitsEmptyView: View {
    let onCreate: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var size = CGSize(width: 400, height: 800)
    private var wide: Bool { size.width > size.height }

    var body: some View {
        Group {
            if wide {
                HStack(spacing: 20) {
                    OrbitMark(height: min(size.height * 0.62, 260)).frame(maxWidth: .infinity)
                    VStack(spacing: 12) { copy }.frame(maxWidth: .infinity)
                }
                .padding(.horizontal)
            } else {
                ScrollView {
                    VStack(spacing: 18) {
                        OrbitMark(height: typeSize.isAccessibilitySize ? 160 : 230)
                        copy
                    }
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity, minHeight: size.height)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { EntryBackground() }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
    }

    @ViewBuilder private var copy: some View {
        Text("Haz espacio a tu\npróximo proyecto")
            .font(.largeTitle.bold())
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        Text("Un plan claro. Un paso posible.\nY un lugar al que volver.")
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        Button(action: onCreate) {
            Text("Crear mi primer Kit")
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .padding(.horizontal, 30)
        .padding(.top, 8)
        .accessibilityIdentifier("emptyState.primaryAction")
        Text("Empieza por lo que quieres conseguir.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Datos derivados para la presentación

extension GoalEntity {
    /// Pasos visibles (sin borrar), en orden.
    var orderedActiveSteps: [StepEntity] {
        steps.filter { $0.deletedAt == nil }.sorted { $0.order < $1.order }
    }

    var activeStepCount: Int { orderedActiveSteps.count }

    var completedStepCount: Int { orderedActiveSteps.filter(\.isCompleted).count }

    /// Primer paso sin completar.
    var nextStep: StepEntity? { orderedActiveSteps.first { !$0.isCompleted } }

    /// Posición del paso (1…n) entre los pasos visibles.
    func position(of step: StepEntity) -> Int {
        (orderedActiveSteps.firstIndex { $0.id == step.id } ?? 0) + 1
    }

    /// Último cambio en el Kit o en cualquiera de sus pasos.
    var lastActivity: Date {
        max(updatedAt, steps.map(\.updatedAt).max() ?? .distantPast)
    }
}
