//
//  StepDetailView.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on 8/10/25.
//

import SwiftUI
import TipKit
import SwiftData
import NaturalLanguage
import os

struct StepDetailView: View {
    @Bindable var stepEntity: StepEntity
    var stepNumber: Int = 1
    @State private var showingEditor = false
    @State private var assistantAfterEdit = false
    /// Al cambiar el ancho (desplegar el Duo, girar un iPhone grande) la vista pasa a otra columna y el
    /// sistema pierde la barra inferior hasta volver a entrar: se retira un instante para que la cree de nuevo.
    @State private var showsBottomActions = true
    @State private var confirmingResolve = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.syncManager) private var syncManager

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Query(sort: \ProgressEntryEntity.notedAt, order: .reverse) private var allEntries: [ProgressEntryEntity]
    @State private var showingSaveProgress = false
    /// La hoja de avance se abre ya en «Me he atascado» (botón Atasco).
    @State private var savingBlocked = false
    @State private var editingEntry: ProgressEntryEntity?
    @State private var assistantLaunch: AssistantLaunch?
    @State private var showingAllProgress = false
    /// Aviso breve tras completar el paso: qué viene después.
    @State private var celebration: Celebration?
    /// Tamaño medido de la vista; hasta que llega, la disposición se estima con el de la columna de
    /// detalle (vista dividida) o el de la ventana. Así el primer fotograma ya es el definitivo.
    @State private var measuredSize: CGSize?
    @Environment(\.detailColumnSize) private var detailColumnSize
    private var layoutSize: CGSize { measuredSize ?? detailColumnSize ?? Self.windowSize }
    private var wideLayout: Bool { TwoColumnLayout.fits(layoutSize) }
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    /// Disposición del Duo cerrado (chips cortos, márgenes de la franja lateral): ancho compacto en una
    /// ventana casi cuadrada. Se decide con el tamaño de la ventana, nunca con el medido: decidir con el
    /// tamaño de la vista algo que cambia ese mismo tamaño acababa en un bucle con la pantalla en blanco.
    private var sideControls: Bool { horizontalSizeClass == .compact && Self.isNearlySquare(Self.windowSize) }
    /// Zonas seguras reales. En el primer fotograma de la entrada llegan a cero (sin barra ni columna
    /// lateral) y el texto se maquetaba a todo el ancho; después se estrechaba y se recolocaba.
    @State private var insets = EdgeInsets()
    private var landscape: Bool { Self.windowSize.width > Self.windowSize.height }
    /// Lo que ocupan la barra superior y la columna de botones en el Duo (medido).
    private static let foldedTopInset: CGFloat = 82
    private static let foldedTrailingInset: CGFloat = 84
    /// En el iPhone Duo (cerrado, o abierto en horizontal) la barra de botones va en vertical junto al
    /// borde derecho y su zona segura llega después del primer fotograma: se reserva a mano.
    private var reservesSideColumn: Bool { DeviceKind.isDuo && (sideControls || landscape) }
    /// «Completar» y «Marcar como pendiente» llevan texto cuando la barra va abajo. En la franja lateral
    /// del Duo (cerrado, o abierto en horizontal) no cabe: solo icono.
    private var actionsShowText: Bool { !reservesSideColumn }

    /// Siguiente paso abierto desde el aviso de completado.
    @State private var openedNextStep: StepEntity?
    @State private var showingKitResult = false

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
    private var stepPendingProposals: Int {
        KitAssistantStore.shared.conversations(for: stepEntity.goal?.id ?? UUID())
            .filter { $0.stepID == stepEntity.id }
            .reduce(0) { $0 + $1.pendingProposalCount }
    }

    /// Días con la sesión del hábito hecha.
    private var doneSessionDays: Set<DateComponents> {
        Set(stepEntries.filter { $0.kind == .session }.map { DateComponents.day(of: $0.notedAt) })
    }

    private var state: StepProgressState {
        stepEntity.progressState(hasEntries: !stepEntries.isEmpty)
    }

    var body: some View {
        // Una sola jerarquía en todas las posturas del iPhone Duo. Cambiarla al entreabrirlo (el paso a
        // un lado del pliegue y su recorrido al otro) recreaba la vista con sus barras: Atrás se quedaba
        // en blanco, aparecía una cápsula vacía en la otra mitad y volver al Kit colgaba la app.
        stepScroll
        .background(alignment: .top) { BrandGlow() }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(stepEntity.goal?.title ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .hidesTabBarSmoothly()
        .onChange(of: horizontalSizeClass) { recreateBottomActions() }
        // Con texto o sin él son botones distintos: al girar el Duo abierto también se rehace la barra.
        .onChange(of: actionsShowText) { recreateBottomActions() }
        // Con el paso abierto ya se ha podido ver el consejo de las acciones: el siguiente puede salir.
        .onAppear { TipFlow.stepActionsSeen = true }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Ayúdame con este paso", systemImage: Symbols.assistant) {
                    assistantLaunch = AssistantLaunch(intent: nil)
                }
                .badge(stepPendingProposals)
                .accessibilityIdentifier("step.assistant")
                .accessibilityHint("Abre el asistente para este paso")
                .accessibilityValue(stepPendingProposals == 0 ? "" : stepPendingProposals == 1 ? String(localized: "Propuesta pendiente") : String(localized: "\(stepPendingProposals) propuestas pendientes"))
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Editar paso", systemImage: "pencil") {
                    showingEditor = true
                }
                .accessibilityIdentifier("step.edit")
                .accessibilityHint("Permite cambiar el título, las descripciones, la fecha y el tiempo del paso")
            }
            // Las tres acciones van en la barra inferior del sistema, como en Mail o Notas: flota sobre
            // el contenido, que se desvanece bajo ella, y en el Duo cerrado (o abierto en horizontal)
            // pasa a la franja lateral. Son botones con título e icono, siempre los mismos: el sistema
            // decide cómo pintarlos en cada postura. Cambiarlos al girar o plegar (texto o solo icono,
            // identidades nuevas) dejaba cápsulas vacías, botones duplicados o perdidos.
            if showsBottomActions {
                ToolbarItemGroup(placement: .bottomBar) {
                    sideToolbarActions
                }
            }
        }
        .sensoryFeedback(.success, trigger: celebration)
        .navigationDestination(isPresented: $showingKitResult) {
            if let kit = stepEntity.goal { ResultReviewView(kit: kit) }
        }
        .navigationDestination(item: $openedNextStep) { step in
            StepDetailView(stepEntity: step, stepNumber: step.goal?.position(of: step) ?? stepNumber + 1)
        }
        // Un toque en la barra no debe quitar un bloqueo sin querer: el botón solo lleva un icono.
        .confirmationDialog("¿Ya puedes seguir con este paso?", isPresented: $confirmingResolve, titleVisibility: .visible) {
            Button("Quitar el bloqueo") {
                withAnimation(.smooth) {
                    try? ProgressLog.resolveBlock(for: stepEntity, context: modelContext)
                }
                syncManager?.handleDataChange()
            }
            Button("Cancelar", role: .cancel) { }
        } message: {
            Text("Tu avance sigue guardado.")
        }
        .sheet(isPresented: $showingEditor, onDismiss: {
            guard assistantAfterEdit else { return }
            assistantAfterEdit = false
            assistantLaunch = AssistantLaunch(intent: nil)
        }) {
            StepEditSheetView(stepEntity: stepEntity, onAskAssistant: { assistantAfterEdit = true })
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
            EditProgressEntrySheet(entry: entry, step: (stepNumber, stepEntity.stepTitle))
        }
    }

    private var stepScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                stepHeader
                // Interior del iPhone Duo o iPad: qué hacer y detalles a la izquierda; avance y recordatorio
                // a la derecha. En estrecho, todo en columna. Mismos hijos en ambos casos (ver StepColumnsLayout).
                StepColumnsLayout(wide: wideLayout, rightColumn: [1, 3]) {
                    VStack(alignment: .leading, spacing: 18) { stepWhatToDo }
                    VStack(alignment: .leading, spacing: 18) { stepProgress }
                    VStack(alignment: .leading, spacing: 18) { stepDetails }
                    VStack(alignment: .leading, spacing: 18) { stepReminder }
                }
            }
            .padding(.horizontal)
            // Un respiro bajo la barra: en el Duo cerrado la cabecera rozaba el cristal y se cortaba.
            .padding(.top, 6)
            .padding(.bottom, 20)
            // Duo cerrado: la columna de botones del borde derecho se reserva siempre a mano y se
            // ignora la zona segura que el sistema aplica después. Así el ancho del texto es el
            // mismo en el primer fotograma de la entrada y en los siguientes, y nada se recoloca.
            .padding(.trailing, reservesSideColumn ? Self.foldedTrailingInset : 0)
            .padding(.top, sideControls && insets.top == 0 ? Self.foldedTopInset : 0)
        }
        .ignoresSafeArea(.container, edges: reservesSideColumn ? .trailing : [])
        // Con las acciones en la barra del sistema, el aviso de completado flota al pie del contenido,
        // justo sobre la barra, sin desplazar nada.
        .overlay(alignment: .bottom) {
            if let celebration {
                CompletionBanner(celebration: celebration) { openNextStep() }
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onGeometryChange(for: EdgeInsets.self) { $0.safeAreaInsets } action: { insets = $0 }
        .balancedHorizontalSafeArea()
        // Con el tamaño de la vista, no de la ventana: en el Duo abierto la columna de detalle es
        // estrecha aunque la ventana sea ancha, y con la ventana salían dos columnas apretadas.
        .onGeometryChange(for: CGSize.self) { $0.size } action: { measuredSize = $0 }
    }

    private var stepHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(text: String(localized: "Paso \(stepNumber) · \(state.label)"),
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
        // En una fila siempre que quepa; si no, «Medio» en vez de «Esfuerzo medio» (Duo cerrado) y solo
        // entonces, en varias filas.
        // En el Duo cerrado se usa la versión corta desde el principio: elegirla al medir hacía que,
        // durante la transición de entrada, se viera «Esfuerzo medio» y luego «Medio».
        if sideControls {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { chips(compact: true) }
                FlowLayout(spacing: 8) { chips(compact: true) }
            }
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { chips(compact: false) }
                HStack(spacing: 8) { chips(compact: true) }
                FlowLayout(spacing: 8) { chips(compact: true) }
            }
        }
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
                Eyebrow(text: String(localized: "Descripción"), color: .secondary)
                ParagraphText(text: stepEntity.descriptionLong)
            }
        }
        if !stepEntity.adaptsTo.isEmpty {
            TintCard {
                HStack(alignment: .top, spacing: 12) {
                    NextMark().padding(.top, 2)
                    VStack(alignment: .leading, spacing: 2) {
                        Eyebrow(text: String(localized: "Planificación recomendada"))
                        Text(stepEntity.adaptsTo).font(.headline)
                    }
                }
            }
        }
    }

    private var stepReminder: some View {
        PlainCard {
            // El mismo interruptor del sistema que en Perfil. Lo que lo deformaba al girar o plegar era
            // que la vista se recreaba al cambiar de disposición; ya no (ver StepColumnsLayout).
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

    /// Todos los avances del paso: el último destacado y los anteriores debajo.
    private var progressHistoryCard: some View {
        let notes = progressNotes
        let visible = showingAllProgress ? notes : Array(notes.prefix(3))
        return PlainCard {
            HStack {
                Text(notes.count == 1 ? String(localized: "Tu avance") : String(localized: "Tus avances")).font(.headline)
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
                            // El lápiz es pequeño: la zona que responde al toque es mayor que el dibujo.
                            Button { editingEntry = entry } label: {
                                Label("Editar nota", systemImage: "pencil")
                                    .labelStyle(.iconOnly)
                                    .padding(14)
                                    .contentShape(.rect)
                            }
                                .padding(-14)
                                .font(.subheadline)
                                .accessibilityIdentifier("progress.editNote")
                        }
                    }
                }
                .padding(.top, 4)
            }
            if notes.count > 3 {
                Button(showingAllProgress ? String(localized: "Ver menos") : String(localized: "Ver todos (\(notes.count))")) {
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
                            RelativeDateText(date: date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text(reason).foregroundStyle(.secondary)
                }
            }
            // Botón visible, no un enlace: es lo primero que conviene hacer con un bloqueo.
            Button(hasBlockHelp ? String(localized: "Ver la ayuda del asistente") : String(localized: "Pedir ayuda al asistente"),
                   systemImage: Symbols.assistant) {
                assistantLaunch = AssistantLaunch(intent: "missing")
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .font(.subheadline.weight(.semibold))
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

    @ViewBuilder private func chips(compact: Bool) -> some View {
        MetaChip(symbol: Symbols.time,
                 text: StepDetailHelpers.formatMinutes(stepEntity.estimateMinutes),
                 color: MetaTint.time)
            .accessibilityLabel(String(localized: "Duración: \(StepDetailHelpers.formatMinutes(stepEntity.estimateMinutes))"))
        let effort = StepDetailHelpers.effortLevelText(for: stepEntity.effortLevel)
        let effortFull = String(localized: "Esfuerzo \(effort.lowercased())")
        MetaChip(symbol: Symbols.effort,
                 text: compact ? effort : effortFull,
                 color: MetaTint.effort,
                 level: EffortLevel.fill(stepEntity.effortLevel))
            .accessibilityLabel(effortFull)
        if let deadline = stepEntity.suggestedDeadline {
            if let repetition = stepEntity.repetition, let last = repetition.lastDate(from: deadline) {
                // Hábito: del primer al último día, y cuántas veces.
                MetaChip(symbol: Symbols.calendar,
                         text: "\(deadline.formatted(.dateTime.day().month(.abbreviated))) – \(last.formatted(.dateTime.day().month(.abbreviated)))",
                         color: MetaTint.date)
                MetaChip(symbol: "repeat", text: repetition.label, color: MetaTint.repeatTint)
            } else {
                MetaChip(symbol: Symbols.calendar,
                         // Un paso hecho no «toca mañana»: su día, sin más.
                         text: stepEntity.isCompleted ? deadline.formatted(.dateTime.day().month(.abbreviated))
                                                      : PlanGrouping.shortDate(deadline),
                         color: MetaTint.date)
                    .accessibilityLabel(String(localized: "Día: \(deadline.formatted(.dateTime.weekday(.wide).day().month(.wide)))"))
            }
        }
    }

    private var completionButton: some View {
        Button {
            withAnimation { toggleStepCompletion() }
        } label: {
            Label(stepEntity.isCompleted ? String(localized: "Marcar como pendiente") : String(localized: "Marcar como completado"),
                  systemImage: stepEntity.isCompleted ? "arrow.uturn.backward" : "checkmark")
                .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("step.toggleCompletion")
        .accessibilityValue(stepEntity.isCompleted ? String(localized: "Completado") : String(localized: "Pendiente"))
    }

    private var saveProgressButton: some View {
        Button {
            showingSaveProgress = true
        } label: {
            Text("Guardar avance").frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("step.saveProgress")
        .accessibilityHint("Anota lo que llevas hecho sin completar el paso")
    }

    /// El asistente ya respondió a este mismo bloqueo: el botón lleva a esa ayuda en vez de pedirla.
    private var hasBlockHelp: Bool {
        guard let blockedAt = stepEntity.blockedAt else { return false }
        return KitAssistantStore.shared.conversations(for: stepEntity.goal?.id ?? UUID())
            .first { $0.stepID == stepEntity.id }?
            .viewModel.messages.contains { $0.sender == .assistant && !$0.isError && $0.timestamp >= blockedAt } ?? false
    }

    private var resolveBlockMenu: some View {
        Button {
            confirmingResolve = true
        } label: {
            Text("Ya lo tengo, seguir").frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .tint(.primaryAction)
        .foregroundStyle(.white)
        .accessibilityIdentifier("step.resolveBlock")
        .accessibilityHint("Quita el bloqueo del paso")
    }

    private func recreateBottomActions() {
        showsBottomActions = false
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            showsBottomActions = true
        }
    }

    static func isNearlySquare(_ size: CGSize) -> Bool {
        size.width < 700 && size.height < 760 && size.width / max(size.height, 1) > 0.6
    }

    /// Tamaño de la ventana activa, para decidir la disposición antes de medir.
    static var windowSize: CGSize {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? scenes.first?.windows.first
        return window?.bounds.size ?? .zero
    }

    /// Acciones como botones de la barra de herramientas (icono y nombre accesible).
    @ViewBuilder private var sideToolbarActions: some View {
        switch state {
        case .done:
            Button {
                withAnimation(.smooth) { toggleStepCompletion() }
            } label: {
                StepActionLabel(title: String(localized: "Marcar como pendiente"), symbol: "arrow.uturn.backward",
                                showsText: actionsShowText)
            }
            .accessibilityIdentifier("step.toggleCompletion")
        case .blocked:
            Button(String(localized: "Ya lo tengo, seguir"), systemImage: "checkmark.circle") {
                confirmingResolve = true
            }
            .accessibilityIdentifier("step.resolveBlock")
            .accessibilityHint("Quita el bloqueo del paso")
            Button(String(localized: "Guardar avance"), systemImage: Symbols.note) {
                savingBlocked = false
                showingSaveProgress = true
            }
            .accessibilityHint("Anota lo que llevas hecho sin completar el paso")
        case .pending, .inProgress:
            Button(String(localized: "Guardar avance"), systemImage: Symbols.note) {
                savingBlocked = false
                showingSaveProgress = true
            }
            .accessibilityIdentifier("step.saveProgress")
            .accessibilityHint("Anota lo que llevas hecho sin completar el paso")
            Button(String(localized: "Me he atascado"), systemImage: "hand.raised") {
                savingBlocked = true
                showingSaveProgress = true
            }
            .accessibilityIdentifier("step.reportBlock")
            .accessibilityHint("Anota qué te frena para retomarlo después")
            // Destacado en el color de la app: es la acción principal del paso.
            Button {
                withAnimation(.smooth) { toggleStepCompletion() }
            } label: {
                StepActionLabel(title: String(localized: "Completar"), symbol: "checkmark", tint: .white,
                                showsText: actionsShowText)
            }
            .buttonStyle(.glassProminent)
            .tint(.primaryAction)
            .foregroundStyle(.white)
            .accessibilityLabel(String(localized: "Marcar como completado"))
            .accessibilityIdentifier("step.toggleCompletion")
        }
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
            AppLog.notifications.error("Step notification preference persistence failed")
            #endif
        }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: - Actions
    private func openNextStep() {
        if celebration?.kitDone == true, stepEntity.goal != nil {
            withAnimation(.smooth) { celebration = nil }
            showingKitResult = true
            return
        }
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
        let shown = Celebration(nextStepID: next?.id, nextTitle: next?.stepTitle, kitDone: next == nil)
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
