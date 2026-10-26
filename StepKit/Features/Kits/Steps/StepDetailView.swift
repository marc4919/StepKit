//
//  StepDetailView.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on 8/10/25.
//

import SwiftUI
import SwiftData
import NaturalLanguage

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
    /// La hoja de avance se abre ya en «Me he atascado» (botón Atasco).
    @State private var savingBlocked = false
    @State private var editingEntry: ProgressEntryEntity?
    @State private var hingePartiallyOpen = false
    @State private var assistantLaunch: AssistantLaunch?
    @State private var showingAllProgress = false
    /// Aviso breve tras completar el paso: qué viene después.
    @State private var celebration: Celebration?
    @State private var wideLayout = false
    /// Siguiente paso abierto desde el aviso de completado.
    @State private var openedNextStep: StepEntity?

    private struct AssistantLaunch: Identifiable {
        let id = UUID()
        let intent: AssistantIntent.ID?
    }

    private var stepEntries: [ProgressEntryEntity] {
        allEntries.filter { $0.stepID == stepEntity.id && $0.ownerID == stepEntity.ownerID && $0.deletedAt == nil }
    }

    /// Avances con nota, del más reciente al más antiguo. Guardar avance añade uno nuevo.
    private var progressNotes: [ProgressEntryEntity] {
        stepEntries.filter { $0.kind == .progress && !$0.note.isEmpty }
    }

    private var lastProgress: ProgressEntryEntity? { progressNotes.first }

    /// El asistente ha dejado una propuesta para este paso (tras un bloqueo, un cambio…).
    private var stepHasProposal: Bool {
        KitAssistantStore.shared.conversations(for: stepEntity.goal?.id ?? UUID())
            .contains { $0.stepID == stepEntity.id && $0.proposals.contains { $0.state == .pending } }
    }

    /// Días con la sesión del hábito hecha.
    private var doneSessionDays: Set<DateComponents> {
        Set(stepEntries.filter { $0.kind == .session }.map { DateComponents.day(of: $0.notedAt) })
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
                Button("Ayúdame con este paso", systemImage: Symbols.assistant) {
                    assistantLaunch = AssistantLaunch(intent: nil)
                }
                .badge(stepHasProposal ? 1 : 0)
                .accessibilityIdentifier("step.assistant")
                .accessibilityValue(stepHasProposal ? "Propuesta pendiente" : "")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Editar paso", systemImage: "pencil") {
                    showingEditor = true
                }
                .accessibilityIdentifier("step.edit")
                .accessibilityHint("Permite cambiar el título, las descripciones, la fecha y el tiempo del paso")
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !wideLayout {
                stepActions
            }
        }
        .sensoryFeedback(.success, trigger: celebration)
        .navigationDestination(item: $openedNextStep) { step in
            StepDetailView(stepEntity: step, stepNumber: step.goal?.position(of: step) ?? stepNumber + 1)
        }
        .sheet(isPresented: $showingEditor) {
            StepEditSheetView(stepEntity: stepEntity)
        }
        .sheet(isPresented: $showingSaveProgress) {
            SaveProgressSheet(step: stepEntity, stepNumber: stepNumber, startsBlocked: savingBlocked)
        }
        .sheet(item: $assistantLaunch) { launch in
            if let kit = stepEntity.goal {
                NavigationStack {
                    KitAssistantChatView(kit: kit,
                                         conversation: KitAssistantStore.shared.conversation(kit: kit, step: stepEntity),
                                         initialIntent: launch.intent)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cerrar") { assistantLaunch = nil }
                            }
                        }
                }
            }
        }
        .sheet(item: $editingEntry) { entry in
            EditProgressEntrySheet(entry: entry, stepLabel: "\(stepNumber) · \(stepEntity.stepTitle)")
        }
    }

    private var stepScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                stepHeader
                if wideLayout {
                    // Interior del iPhone Duo o iPad: qué hacer a la izquierda; tu avance y el recordatorio a la derecha.
                    HStack(alignment: .top, spacing: 20) {
                        VStack(alignment: .leading, spacing: 18) {
                            stepWhatToDo
                            stepDetails
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        VStack(alignment: .leading, spacing: 18) {
                            stepProgress
                            stepReminder
                            // Con dos columnas, las acciones van aquí, bajo el recordatorio, y no en una barra abajo.
                            stepActions
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    stepWhatToDo
                    stepProgress
                    stepDetails
                    stepReminder
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .onGeometryChange(for: Bool.self) { TwoColumnLayout.fits($0.size) } action: { wideLayout = $0 }
    }

    private var stepActions: some View {
        VStack(spacing: 10) {
            if let celebration {
                CompletionBanner(celebration: celebration) { openNextStep() }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            bottomActions
        }
        // En pantallas anchas los botones no se estiran de borde a borde.
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity)
    }

    private var stepHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(text: "Paso \(stepNumber) · \(state.label)",
                    color: state == .pending ? .accentColor : state.tint)
            Text(stepEntity.stepTitle)
                .font(.largeTitle.bold())
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
    }

    @ViewBuilder private var stepWhatToDo: some View {
        if !stepEntity.descriptionShort.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("Al terminar").font(.headline)
                Text(stepEntity.descriptionShort).foregroundStyle(.secondary)
            }
        }
        FlowLayout(spacing: 8) { chips }
        if stepEntity.repetition != nil, !stepEntity.sessionDates.isEmpty {
            HabitSessionsCard(step: stepEntity, doneDays: doneSessionDays) { day in
                withAnimation(.snappy) {
                    try? ProgressLog.toggleSession(of: stepEntity, on: day, context: modelContext)
                }
                syncManager?.handleDataChange()
            } onCompleteStep: {
                withAnimation { toggleStepCompletion() }
            }
        }
    }

    @ViewBuilder private var stepProgress: some View {
        if let reason = stepEntity.blockedReason {
            blockedCards(reason: reason)
        } else if !progressNotes.isEmpty {
            progressHistoryCard
        }
    }

    @ViewBuilder private var stepDetails: some View {
        if !stepEntity.descriptionLong.isEmpty, stepEntity.descriptionLong != stepEntity.descriptionShort {
            PlainCard {
                Eyebrow(text: "Descripción", color: .secondary)
                ParagraphText(text: stepEntity.descriptionLong)
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
    }

    private var stepReminder: some View {
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

    /// Todos los avances del paso: el último destacado y los anteriores debajo.
    private var progressHistoryCard: some View {
        let notes = progressNotes
        let visible = showingAllProgress ? notes : Array(notes.prefix(3))
        return PlainCard {
            HStack {
                Text(notes.count == 1 ? "Tu avance" : "Tus avances").font(.headline)
                Spacer()
                if notes.count > 1 {
                    Text("\(notes.count)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            ForEach(Array(visible.enumerated()), id: \.element.id) { index, entry in
                HStack(alignment: .top, spacing: 12) {
                    Rectangle()
                        .fill(index == 0 ? Color.accentColor : Color.secondary.opacity(0.35))
                        .frame(width: 3)
                        .clipShape(.capsule)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.note)
                            .foregroundStyle(index == 0 ? .primary : .secondary)
                        HStack {
                            Label(entry.notedAt.formatted(.dateTime.day().month(.abbreviated).hour().minute()), systemImage: Symbols.calendar)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Editar nota", systemImage: "pencil") { editingEntry = entry }
                                .font(.subheadline)
                                .labelStyle(.iconOnly)
                                .accessibilityIdentifier("progress.editNote")
                        }
                    }
                }
                .padding(.top, 4)
            }
            if notes.count > 3 {
                Button(showingAllProgress ? "Ver menos" : "Ver todos (\(notes.count))") {
                    withAnimation(.snappy) { showingAllProgress.toggle() }
                }
                .font(.subheadline)
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
            Button("Me falta algo: pedir ayuda", systemImage: Symbols.assistant) {
                assistantLaunch = AssistantLaunch(intent: "missing")
            }
            .font(.subheadline)
            .accessibilityIdentifier("step.blockedHelp")
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
                 color: MetaTint.effort,
                 level: EffortLevel.fill(stepEntity.effortLevel))
        if let deadline = stepEntity.suggestedDeadline {
            if let repetition = stepEntity.repetition, let last = repetition.lastDate(from: deadline) {
                // Hábito: del primer al último día, y cuántas veces.
                MetaChip(symbol: Symbols.calendar,
                         text: "\(deadline.formatted(.dateTime.day().month(.abbreviated))) – \(last.formatted(.dateTime.day().month(.abbreviated)))",
                         color: MetaTint.date)
                MetaChip(symbol: "repeat", text: repetition.label, color: MetaTint.repeatTint)
            } else {
                MetaChip(symbol: Symbols.calendar,
                         text: deadline.formatted(.dateTime.day().month(.abbreviated)),
                         color: MetaTint.date)
            }
        }
    }

    private var completionButton: some View {
        Button {
            withAnimation { toggleStepCompletion() }
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
        .buttonStyle(.glassProminent)
        .accessibilityIdentifier("step.resolveBlock")
    }

    @ViewBuilder private var bottomActions: some View {
        let compactHeight = verticalSizeClass == .compact
        let layout = compactHeight ? AnyLayout(HStackLayout(spacing: 8)) : AnyLayout(VStackLayout(spacing: 8))
        layout {
            switch state {
            case .done:
                completionButton.buttonStyle(.glass)
            case .blocked:
                resolveBlockMenu
                if !compactHeight {
                    Text("Al resolverlo, el paso vuelve a «En curso». Tu avance se conserva.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            case .pending, .inProgress:
                // Tres acciones a la vista, una al lado de otra, como controles de Liquid Glass.
                GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    actionTile("Avance", symbol: Symbols.note, identifier: "step.saveProgress",
                               accessibilityLabel: "Guardar avance") {
                        savingBlocked = false
                        showingSaveProgress = true
                    }
                    actionTile("Atasco", symbol: "hand.raised", identifier: "step.reportBlock",
                               accessibilityLabel: "Me he atascado") {
                        savingBlocked = true
                        showingSaveProgress = true
                    }
                    actionTile("Completar", symbol: "checkmark", prominent: true, identifier: "step.toggleCompletion",
                               accessibilityLabel: "Marcar como completado") {
                        withAnimation(.smooth) { toggleStepCompletion() }
                    }
                }
                }
            }
        }
        .controlSize(compactHeight ? .regular : .large)
        .padding(.horizontal, wideLayout ? 0 : 16)
        .padding(.vertical, compactHeight ? 6 : 10)
    }

    private func actionTile(_ title: String, symbol: String, prominent: Bool = false, identifier: String,
                            accessibilityLabel: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: symbol).font(.title3.weight(.semibold))
                // En pantallas estrechas (iPhone Duo cerrado) el texto se ajusta antes que partirse.
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .allowsTightening(true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(prominent ? AnyPrimitiveButtonStyle(.glassProminent) : AnyPrimitiveButtonStyle(.glass))
        .accessibilityLabel(accessibilityLabel ?? title)
        .accessibilityIdentifier(identifier)
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
    private func openNextStep() {
        guard let id = celebration?.nextStepID,
              let next = stepEntity.goal?.orderedActiveSteps.first(where: { $0.id == id }) else { return }
        withAnimation(.smooth) { celebration = nil }
        openedNextStep = next
    }

    private func toggleStepCompletion() {
        let completing = !stepEntity.isCompleted
        try? ProgressLog.toggleCompletion(of: stepEntity, context: modelContext)
        syncManager?.handleDataChange()
        guard completing else {
            celebration = nil
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            return
        }
        let next = stepEntity.goal?.orderedActiveSteps.first { !$0.isCompleted }
        let shown = Celebration(nextStepID: next?.id, nextTitle: next?.stepTitle)
        celebration = shown
        Task { @MainActor in
            // Tiempo suficiente para tocar «Siguiente» sin que el aviso estorbe.
            try? await Task.sleep(for: .seconds(6))
            if celebration == shown { withAnimation(.smooth) { celebration = nil } }
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

/// Texto largo en párrafos cortos: respeta los saltos que trae y, si no hay, agrupa de dos en dos frases.
struct ParagraphText: View {
    let text: String

    static func paragraphs(of text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let explicit = trimmed.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        if explicit.count > 1 || trimmed.count < 220 { return explicit }
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = trimmed
        var sentences: [String] = []
        tokenizer.enumerateTokens(in: trimmed.startIndex..<trimmed.endIndex) { range, _ in
            sentences.append(trimmed[range].trimmingCharacters(in: .whitespaces))
            return true
        }
        guard sentences.count > 2 else { return [trimmed] }
        return stride(from: 0, to: sentences.count, by: 2).map {
            sentences[$0..<min($0 + 2, sentences.count)].joined(separator: " ")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(Self.paragraphs(of: text).enumerated()), id: \.offset) { _, paragraph in
                Text(paragraph)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Sesiones de un paso que se repite: cada círculo es un día (o una semana) y se marca al hacerlo.
struct HabitSessionsCard: View {
    let step: StepEntity
    let doneDays: Set<DateComponents>
    let onToggle: (Date) -> Void
    let onCompleteStep: () -> Void

    private var dates: [Date] { step.sessionDates }
    private var doneCount: Int { dates.filter { doneDays.contains(DateComponents.day(of: $0)) }.count }

    var body: some View {
        PlainCard {
            HStack(alignment: .firstTextBaseline) {
                Text("Tus sesiones").font(.headline)
                Spacer()
                Text("\(doneCount) de \(dates.count)")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(doneCount == dates.count ? MetaTint.done : .secondary)
                    .contentTransition(.numericText())
            }
            ProgressView(value: Double(doneCount), total: Double(max(dates.count, 1)))
                .tint(MetaTint.repeatTint)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 10) {
                ForEach(dates, id: \.self) { date in
                    sessionButton(date)
                }
            }
            if doneCount == dates.count, !step.isCompleted {
                VStack(spacing: 8) {
                    Label("Sesiones cumplidas", systemImage: "checkmark.seal.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MetaTint.done)
                    Button(action: onCompleteStep) {
                        Text("Completar paso").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(MetaTint.done)
                }
                .frame(maxWidth: .infinity)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .sensoryFeedback(.success, trigger: doneCount == dates.count)
    }

    private func sessionButton(_ date: Date) -> some View {
        let done = doneDays.contains(DateComponents.day(of: date))
        let isToday = Calendar.current.isDateInToday(date)
        let weekly = step.repetition?.every == .week
        return Button { onToggle(date) } label: {
            VStack(spacing: 3) {
                Text(weekly ? "S\((dates.firstIndex(of: date) ?? 0) + 1)"
                            : date.formatted(.dateTime.weekday(.narrow)))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isToday ? Color.accentColor : .secondary)
                ZStack {
                    Circle()
                        .fill(done ? MetaTint.repeatTint : Color.clear)
                    Circle()
                        .strokeBorder(done ? MetaTint.repeatTint : (isToday ? Color.accentColor : Color.secondary.opacity(0.35)),
                                      lineWidth: isToday && !done ? 2 : 1.5)
                    if done {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Text(date.formatted(.dateTime.day()))
                            .font(.caption.weight(.medium).monospacedDigit())
                            .foregroundStyle(.primary)
                    }
                }
                .frame(width: 34, height: 34)
            }
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: done)
        .accessibilityLabel("\(step.repetition?.sessionName(dates.firstIndex(of: date) ?? 0) ?? ""), \(date.formatted(.dateTime.weekday(.wide).day().month(.wide)))")
        .accessibilityValue(done ? "Hecha" : "Pendiente")
        .accessibilityAddTraits(done ? .isSelected : [])
    }
}

/// Para alternar entre estilos de botón del sistema sin duplicar la vista.
struct AnyPrimitiveButtonStyle: PrimitiveButtonStyle {
    private let make: (Configuration) -> AnyView

    init<S: PrimitiveButtonStyle>(_ style: S) {
        make = { AnyView(style.makeBody(configuration: $0)) }
    }

    func makeBody(configuration: Configuration) -> some View { make(configuration) }
}

// MARK: - Aviso al completar

struct Celebration: Equatable {
    let id = UUID()
    let nextStepID: UUID?
    let nextTitle: String?
}

/// Confirmación breve y visible al completar: el check se anima y dice qué viene después.
private struct CompletionBanner: View {
    let celebration: Celebration
    let onOpenNext: () -> Void
    @State private var appeared = false

    var body: some View {
        if celebration.nextStepID != nil {
            Button(action: onOpenNext) { content(showsChevron: true) }
                .buttonStyle(.plain)
                .accessibilityHint("Abre el siguiente paso")
                .accessibilityIdentifier("step.openNext")
        } else {
            content(showsChevron: false)
        }
    }

    private func content(showsChevron: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title)
                .foregroundStyle(.green)
                .symbolEffect(.bounce, value: appeared)
            VStack(alignment: .leading, spacing: 2) {
                Text("¡Paso completado!").font(.headline)
                Text(celebration.nextTitle.map { "Siguiente: \($0)" } ?? "Era el último paso del Kit.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .contentShape(.rect(cornerRadius: 22))
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 22))
        .padding(.horizontal)
        .onAppear { appeared = true }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }
}
