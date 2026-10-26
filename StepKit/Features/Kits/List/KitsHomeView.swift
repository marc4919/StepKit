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
    let allActiveKits: [GoalEntity]
    let allCompletedKits: [GoalEntity]
    @Bindable var viewModel: KitsViewModel
    /// iPhone: abre el Kit en la pila. iPad: lo selecciona en la columna de detalle.
    var isCompact = true
    @Query(sort: \ProgressEntryEntity.notedAt, order: .reverse) private var allEntries: [ProgressEntryEntity]
    @State private var reviewingKit: GoalEntity?
    @State private var continuingStep: StepEntity?

    init(activeKits: [GoalEntity], completedKits: [GoalEntity], viewModel: KitsViewModel, isCompact: Bool = true) {
        self.allActiveKits = activeKits
        self.allCompletedKits = completedKits
        self.viewModel = viewModel
        self.isCompact = isCompact
    }

    private var activeKits: [GoalEntity] { allActiveKits.filter { !viewModel.leavingKitIDs.contains($0.id) } }
    private var completedKits: [GoalEntity] { allCompletedKits.filter { !viewModel.leavingKitIDs.contains($0.id) } }

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
                // List para conservar el gesto clásico de deslizar para eliminar.
                List {
                    if !pendingResultKits.isEmpty {
                        // Discretos: una fila con la bandera, sin tarjeta grande ni todo en verde.
                        Section {
                            ForEach(pendingResultKits) { kit in
                                Button { startReview(of: kit) } label: { PendingResultRow(kit: kit) }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("kit.row")
                                    .accessibilityLabel("Kit: \(kit.title)")
                                    .accessibilityValue("Todos los pasos hechos, falta revisar el resultado")
                                    .listRowInsets(EdgeInsets())
                                    .deletable { viewModel.prepareForDeletion(kit) }
                            }
                        } header: {
                            Text("Por revisar")
                                .font(.title3.bold())
                                .foregroundStyle(Color(.label))
                                .textCase(nil)
                        }
                    }
                    if let kit = continueKit {
                        Section {
                            ContinueCard(kit: kit, lastProgress: lastProgress(of: kit)) {
                                if let step = kit.nextStep {
                                    continuingStep = step
                                } else {
                                    open(kit)
                                }
                            } onOpenKit: {
                                open(kit)
                            }
                            .cardRow()
                            .deletable { viewModel.prepareForDeletion(kit) }
                        }
                    }
                    if !otherKits.isEmpty {
                        section(title: continueKit != nil ? "Otros Kits en curso" : "En curso", kits: otherKits)
                    }
                    if !confirmedKits.isEmpty {
                        section(title: "Terminados", kits: confirmedKits)
                    }
                }
                .listStyle(.insetGrouped)
                .listSectionSpacing(22)
                .scrollContentBackground(.hidden)
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
        Section {
            ForEach(kits) { kit in
                Button { open(kit) } label: { KitHomeRow(kit: kit, lastProgress: lastProgress(of: kit)) }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("kit.row")
                    .accessibilityLabel("Kit: \(kit.title)")
                    .accessibilityValue("\(kit.completedStepCount) de \(kit.activeStepCount) pasos")
                    .listRowInsets(EdgeInsets())
                    .alignmentGuide(.listRowSeparatorLeading) { _ in 72 }
                    .deletable { viewModel.prepareForDeletion(kit) }
            }
        } header: {
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(Color(.label))
                .textCase(nil)
        }
    }

    private func open(_ kit: GoalEntity) {
        if isCompact {
            viewModel.navigationPath.append(kit.id)
        } else {
            viewModel.selectKit(kit)
        }
    }

    /// En iPhone, la revisión se abre encima del plan del Kit para que «Volver al plan» sea un simple retroceso.
    private func startReview(of kit: GoalEntity) {
        guard isCompact else { reviewingKit = kit; return }
        viewModel.reviewOnOpenKitID = kit.id
        viewModel.navigationPath.append(kit.id)
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
                .accessibilityLabel("Kit: \(kit.title)")
                .accessibilityValue("\(kit.completedStepCount) de \(kit.activeStepCount) pasos")
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
                VStack(spacing: 10) {
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

private struct PendingResultRow: View {
    let kit: GoalEntity

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "flag.checkered")
                .font(.title3)
                .foregroundStyle(MetaTint.done)
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(kit.title).font(.headline).foregroundStyle(.primary)
                Text("\(kit.activeStepCount) de \(kit.activeStepCount) pasos · Revisa el resultado")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(.rect)
    }
}

private struct PendingResultCard: View {
    let kit: GoalEntity
    @Environment(\.dynamicTypeSize) private var typeSize
    let onReview: () -> Void
    let onBackToPlan: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow(text: "Pasos terminados · falta revisar el resultado", color: MetaTint.done)
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                : AnyLayout(HStackLayout(spacing: 14))
            layout {
                ProgressRing(done: kit.completedStepCount, total: kit.activeStepCount, size: 70)
                VStack(alignment: .leading, spacing: 4) {
                    Text(kit.title).font(.title2.bold())
                        .accessibilityIdentifier("kit.row")
                        .accessibilityLabel("Kit: \(kit.title)")
                    Text("\(kit.completedStepCount) de \(kit.activeStepCount) pasos terminados")
                        .foregroundStyle(.secondary)
                    Text("Resultado sin confirmar")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MetaTint.done)
                }
            }
            TintCard(tint: MetaTint.done, strength: 0.12) {
                HStack(alignment: .top, spacing: 12) {
                    IconChip(symbol: "flag.checkered", color: MetaTint.done)
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var copyVisible = false
    @State private var size = CGSize(width: 400, height: 800)
    private var wide: Bool { size.width > size.height }

    var body: some View {
        Group {
            if wide {
                HStack(spacing: 20) {
                    OrbitMark(height: min(size.height * 0.62, 260), animated: true).frame(maxWidth: .infinity)
                    VStack(spacing: 12) { copy }.frame(maxWidth: .infinity)
                }
                .padding(.horizontal)
            } else {
                ScrollView {
                    VStack(spacing: 18) {
                        OrbitMark(height: typeSize.isAccessibilitySize ? 160 : 230, animated: true)
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
        .onAppear {
            if reduceMotion { copyVisible = true; return }
            withAnimation(.easeOut(duration: 0.6).delay(0.9)) { copyVisible = true }
        }
    }

    @ViewBuilder private var copy: some View {
        copyContent
            .opacity(copyVisible ? 1 : 0)
            .offset(y: copyVisible ? 0 : 12)
    }

    @ViewBuilder private var copyContent: some View {
        Text("Haz espacio a tu\npróximo objetivo")
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
        .frame(maxWidth: 420)
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

private extension View {
    /// Fila de List que muestra una tarjeta propia sin fondo ni separadores del sistema.
    func cardRow() -> some View {
        listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }

    /// Deslizar para eliminar y menú contextual, como en la lista clásica.
    func deletable(_ action: @escaping () -> Void) -> some View {
        swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("Eliminar", systemImage: "trash", action: action).tint(.red)
        }
        .contextMenu {
            Button("Eliminar Kit", systemImage: "trash", role: .destructive, action: action)
        }
    }
}
