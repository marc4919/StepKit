//
//  StepDetailView.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on 8/10/25.
//

import SwiftUI
import SwiftData

struct StepDetailView: View {
    @Bindable var stepEntity: StepEntity
    var stepNumber: Int = 1
    @State private var showingEditor = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.syncManager) private var syncManager

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Query(sort: \ProgressEntryEntity.notedAt, order: .reverse) private var allEntries: [ProgressEntryEntity]
    @State private var showingSaveProgress = false
    @State private var editingEntry: ProgressEntryEntity?
    @State private var hingePartiallyOpen = false

    private var stepEntries: [ProgressEntryEntity] {
        allEntries.filter { $0.stepID == stepEntity.id && $0.ownerID == stepEntity.ownerID && $0.deletedAt == nil }
    }

    private var lastProgress: ProgressEntryEntity? {
        stepEntries.first { $0.kind == .progress && !$0.note.isEmpty }
    }

    private var state: StepProgressState {
        stepEntity.progressState(hasEntries: !stepEntries.isEmpty)
    }

    var body: some View {
        Group {
            if hingePartiallyOpen, #available(iOS 27.1, *) {
                // iPhone Duo entreabierto: el paso a un lado del pliegue, su recorrido y Guardar avance al otro.
                ArrangementView {
                    stepScroll
                } secondary: {
                    foldedProgressSide
                }
                .arrangementViewStyle(.split)
            } else {
                stepScroll
            }
        }
        .modifier(HingeObserver(isPartiallyOpen: $hingePartiallyOpen))
        .background(alignment: .top) { BrandGlow() }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(stepEntity.goal?.title ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Editar paso", systemImage: "pencil") {
                    showingEditor = true
                }
                .accessibilityIdentifier("step.edit")
                .accessibilityHint("Permite cambiar el título y las descripciones del paso")
            }
        }
        .safeAreaInset(edge: .bottom) { bottomActions }
        .sheet(isPresented: $showingEditor) {
            StepEditSheetView(stepEntity: stepEntity)
        }
        .sheet(isPresented: $showingSaveProgress) {
            SaveProgressSheet(step: stepEntity, stepNumber: stepNumber)
        }
        .sheet(item: $editingEntry) { entry in
            EditProgressEntrySheet(entry: entry, stepLabel: "\(stepNumber) · \(stepEntity.stepTitle)")
        }
    }

    private var stepScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Eyebrow(text: "Paso \(stepNumber) · \(state.label)",
                            color: state == .pending ? .accentColor : state.tint)
                    Text(stepEntity.stepTitle)
                        .font(.largeTitle.bold())
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                }
                if !stepEntity.descriptionShort.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Al terminar").font(.headline)
                        Text(stepEntity.descriptionShort).foregroundStyle(.secondary)
                    }
                }
                ViewThatFits {
                    HStack(spacing: 8) { chips }
                    VStack(alignment: .leading, spacing: 8) { chips }
                }
                if let reason = stepEntity.blockedReason {
                    blockedCards(reason: reason)
                } else if let entry = lastProgress {
                    lastProgressCard(entry)
                }
                if !stepEntity.descriptionLong.isEmpty, stepEntity.descriptionLong != stepEntity.descriptionShort {
                    PlainCard {
                        Eyebrow(text: "Descripción", color: .secondary)
                        Text(stepEntity.descriptionLong)
                    }
                }
                if !stepEntity.adaptsTo.isEmpty {
                    TintCard {
                        HStack(alignment: .top, spacing: 12) {
                            NextMark().padding(.top, 2)
                            VStack(alignment: .leading, spacing: 2) {
                                Eyebrow(text: "Planificación recomendada")
                                Text(stepEntity.adaptsTo).font(.headline)
                            }
                        }
                    }
                }
                PlainCard {
                    Toggle(isOn: Binding(
                        get: { stepEntity.notificationEnabled },
                        set: { _ in toggleStepNotification() }
                    )) {
                        Label {
                            Text("Recordatorio")
                        } icon: {
                            IconChip(symbol: "bell.fill", color: .red, size: 28)
                        }
                    }
                    .accessibilityHint("Activa o desactiva el recordatorio de este paso")
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }

    /// Lado secundario en el Duo entreabierto. Plegar no abre ningún formulario.
    private var foldedProgressSide: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Tu recorrido en este paso").font(.headline)
                if stepEntries.isEmpty {
                    Text("Aún no has guardado avances en este paso.").foregroundStyle(.secondary)
                }
                ForEach(stepEntries.prefix(4)) { entry in
                    HStack(alignment: .top, spacing: 12) {
                        IconChip(symbol: entry.kind == .blocked ? Symbols.blocked : "circle.lefthalf.filled",
                                 color: entry.kind == .blocked ? .red : .accentColor, size: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.notedAt.formatted(.dateTime.day().month(.abbreviated)))
                                .font(.caption).foregroundStyle(.secondary)
                            Text(entry.note.isEmpty ? "Avance guardado" : entry.note)
                        }
                    }
                }
                if !stepEntity.isCompleted {
                    Button { showingSaveProgress = true } label: {
                        Text("Guardar avance").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                Text("Plegar el teléfono no abre ningún formulario: guardas cuando quieras.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    private func lastProgressCard(_ entry: ProgressEntryEntity) -> some View {
        PlainCard {
            HStack(alignment: .top, spacing: 12) {
                Rectangle().fill(Color.accentColor).frame(width: 3).clipShape(.capsule)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tu último avance").font(.headline)
                    Text(entry.note).foregroundStyle(.secondary)
                    HStack {
                        Label(entry.notedAt.formatted(.dateTime.day().month(.abbreviated)), systemImage: Symbols.calendar)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Editar nota", systemImage: "pencil") { editingEntry = entry }
                            .font(.subheadline)
                            .accessibilityIdentifier("progress.editNote")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func blockedCards(reason: String) -> some View {
        TintCard(tint: .red, strength: 0.10) {
            HStack(alignment: .top, spacing: 12) {
                IconChip(symbol: Symbols.blocked, color: .red)
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("Qué te frena").font(.headline)
                        Spacer()
                        if let date = stepEntity.blockedAt {
                            Text(date, format: .relative(presentation: .named))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text(reason).foregroundStyle(.secondary)
                }
            }
        }
        if let entry = lastProgress {
            PlainCard {
                HStack(alignment: .top, spacing: 12) {
                    IconChip(symbol: "checkmark", color: .green)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Ya tienes").font(.headline)
                        Text(entry.note).foregroundStyle(.secondary)
                        Text("Tu avance sigue guardado.").font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder private var chips: some View {
        MetaChip(symbol: Symbols.time,
                 text: StepDetailHelpers.formatMinutes(stepEntity.estimateMinutes),
                 color: MetaTint.time)
        MetaChip(symbol: Symbols.effort,
                 text: "Esfuerzo \(StepDetailHelpers.effortLevelText(for: stepEntity.effortLevel).lowercased())",
                 color: MetaTint.effort)
        if let deadline = stepEntity.suggestedDeadline {
            MetaChip(symbol: Symbols.calendar,
                     text: deadline.formatted(.dateTime.day().month(.abbreviated)),
                     color: MetaTint.date)
        }
    }

    private var completionButton: some View {
        Button {
            withAnimation { toggleStepCompletion() }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } label: {
            Label(stepEntity.isCompleted ? "Marcar como pendiente" : "Marcar como completado",
                  systemImage: stepEntity.isCompleted ? "arrow.uturn.backward" : "checkmark")
                .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("step.toggleCompletion")
        .accessibilityValue(stepEntity.isCompleted ? "Completado" : "Pendiente")
    }

    private var saveProgressButton: some View {
        Button {
            showingSaveProgress = true
        } label: {
            Text("Guardar avance").frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("step.saveProgress")
    }

    private var resolveBlockMenu: some View {
        Menu {
            Button("Ya está resuelto", systemImage: "checkmark") {
                try? ProgressLog.resolveBlock(for: stepEntity, context: modelContext)
                syncManager?.handleDataChange()
            }
            Button("Guardar avance", systemImage: Symbols.note) { showingSaveProgress = true }
        } label: {
            Text("Resolver bloqueo").frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .accessibilityIdentifier("step.resolveBlock")
    }

    @ViewBuilder private var bottomActions: some View {
        let compactHeight = verticalSizeClass == .compact
        let layout = compactHeight ? AnyLayout(HStackLayout(spacing: 8)) : AnyLayout(VStackLayout(spacing: 8))
        layout {
            switch state {
            case .done:
                completionButton.buttonStyle(.bordered)
            case .blocked:
                resolveBlockMenu
                if !compactHeight {
                    Text("Al resolverlo, el paso vuelve a «En curso». Tu avance se conserva.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            case .pending, .inProgress:
                saveProgressButton.buttonStyle(.borderedProminent)
                completionButton.buttonStyle(.bordered)
            }
        }
        .controlSize(compactHeight ? .regular : .large)
        .padding(.horizontal)
        .padding(.vertical, compactHeight ? 6 : 10)
        .background(.bar)
    }

    // MARK: - Step Notification Toggle
    private func toggleStepNotification() {
        stepEntity.notificationEnabled.toggle()
        stepEntity.markModified()

        if stepEntity.notificationEnabled {
            Task {
                await NotificationService.shared.scheduleNotification(for: stepEntity)
            }
        } else {
            NotificationService.shared.cancelNotification(for: stepEntity.id)
        }

        do {
            try modelContext.save()
        } catch {
            #if DEBUG
            print("Step notification preference persistence failed")
            #endif
        }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: - Actions
    private func toggleStepCompletion() {
        // Actualizar el StepEntity directamente
        stepEntity.isCompleted.toggle()
        stepEntity.markModified()  // También marca el goal parent

        // Actualizar progreso del goal
        if let goalEntity = stepEntity.goal {
            goalEntity.progress = goalEntity.computedProgress
            goalEntity.markModified()
        }

        // Guardar cambios
        do {
            try modelContext.save()

            // Trigger sync después de cambio
            syncManager?.handleDataChange()
        } catch {
            #if DEBUG
            print("Step completion persistence failed")
            #endif
        }
    }
}

#Preview("Pendiente") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: GoalEntity.self, StepEntity.self, configurations: config)
    let stepEntity = StepEntity(
        stepTitle: "Paso pendiente",
        descriptionShort: "Descripción corta",
        descriptionLong: "Descripción larga del paso",
        estimateMinutes: 45,
        suggestedDeadline: Date(),
        effortLevel: "medium",
        adaptsTo: "Se adapta a tu disponibilidad",
        isCompleted: false
    )
    container.mainContext.insert(stepEntity)

    return NavigationStack {
        StepDetailView(stepEntity: stepEntity, stepNumber: 1)
    }
    .modelContainer(container)
}

#Preview("Completado") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: GoalEntity.self, StepEntity.self, configurations: config)
    let stepEntity = StepEntity(
        stepTitle: "Paso completado",
        descriptionShort: "Descripción corta",
        descriptionLong: "Descripción larga del paso completado",
        estimateMinutes: 30,
        suggestedDeadline: Date(),
        effortLevel: "low",
        adaptsTo: "",
        isCompleted: true
    )
    container.mainContext.insert(stepEntity)

    return NavigationStack {
        StepDetailView(stepEntity: stepEntity, stepNumber: 3)
    }
    .modelContainer(container)
}

/// Observa la bisagra del iPhone Duo (iOS 27.1+). En otros dispositivos no hace nada.
struct HingeObserver: ViewModifier {
    @Binding var isPartiallyOpen: Bool

    func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content.onHingeChange { _, context in
                isPartiallyOpen = context.hinge?.status == .partiallyOpen
            }
        } else {
            content
        }
    }
}
