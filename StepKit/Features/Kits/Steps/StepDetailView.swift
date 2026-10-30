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
    // Se parte del tamaño de la ventana para que la primera imagen ya tenga la disposición correcta:
    // si se esperara a medir la vista, en el Duo cerrado se vería el reajuste al entrar.
    /// Tamaño medido de la vista; hasta que llega, la disposición se estima con el de la columna de
    /// detalle (vista dividida) o el de la ventana. Así el primer fotograma ya es el definitivo.
    @State private var measuredSize: CGSize?
    @Environment(\.detailColumnSize) private var detailColumnSize
    private var layoutSize: CGSize { measuredSize ?? detailColumnSize ?? Self.windowSize }
    private var wideLayout: Bool { TwoColumnLayout.fits(layoutSize) }
    /// Si el sistema dibuja las barras en vertical (iPhone Duo cerrado, y abierto en horizontal), lo dice
    /// `toolbarVerticalEdge` (iOS 27.1): las acciones van entonces en la barra del sistema. Sin ese dato,
    /// se estima con el tamaño de la ventana, nunca con el medido: la barra de acciones propia resta
    /// altura a la vista y en un iPhone eso la volvía «casi cuadrada» en un bucle sin fin.
    @State private var toolbarIsVertical: Bool?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    /// Solo en ancho compacto (Duo cerrado): abierto en horizontal las barras también van en vertical,
    /// pero con las acciones dentro se desbordaban en un menú «…»; ahí se queda la barra propia abajo.
    private var sideControls: Bool {
        horizontalSizeClass == .compact && (toolbarIsVertical ?? Self.isNearlySquare(Self.windowSize))
    }
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
    /// Acciones dentro de la barra de herramientas (Duo cerrado) en vez de botones grandes.
    /// Las acciones del paso van siempre en la barra inferior del sistema (botones de cristal con
    /// icono y texto, «Completar» destacado): en el Duo cerrado el sistema la pinta en vertical.
    private var actionsInToolbar: Bool { true }
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
        .hidesTabBarSmoothly()
        // Con el paso abierto ya se ha podido ver el consejo de las acciones: el siguiente puede salir.
        .onAppear { TipFlow.stepActionsSeen = true }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Ayúdame con este paso", systemImage: Symbols.assistant) {
                    assistantLaunch = AssistantLaunch(intent: nil)
                }
                .badge(stepPendingProposals)
                .accessibilityIdentifier("step.assistant")
                .accessibilityValue(stepPendingProposals == 0 ? "" : stepPendingProposals == 1 ? String(localized: "Propuesta pendiente") : String(localized: "\(stepPendingProposals) propuestas pendientes"))
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Editar paso", systemImage: "pencil") {
                    showingEditor = true
                }
                .accessibilityIdentifier("step.edit")
                .accessibilityHint("Permite cambiar el título, las descripciones, la fecha y el tiempo del paso")
            }
        }
        // Duo cerrado: las acciones van en la barra inferior del sistema, que allí se dibuja en vertical
        // junto al borde. En el resto de casos la barra es propia y va dentro de `stepScroll`.
        .toolbar {
            if sideControls {
                ToolbarItemGroup(placement: .bottomBar) {
                    sideToolbarActions
                }
            }
        }
        // Fuera del Duo cerrado no se toca la visibilidad: ocultar la barra a mano dejaba su cápsula
        // de cristal vacía en el Duo al plegar (el sistema reserva el hueco aunque no haya botones).
        .toolbarVisibility(sideControls ? .visible : .automatic, for: .bottomBar)
        .overlay(alignment: .bottom) {
            // Con las acciones en la barra, el aviso de completado flota abajo sin desplazar nada.
            if sideControls, let celebration {
                CompletionBanner(celebration: celebration) { openNextStep() }
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background {
            if #available(iOS 27.1, *) {
                ToolbarVerticalEdgeProbe { toolbarIsVertical = $0 }
            }
        }
        .sensoryFeedback(.success, trigger: celebration)
        .navigationDestination(isPresented: $showingKitResult) {
            if let kit = stepEntity.goal { ResultReviewView(kit: kit) }
        }
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
        // La barra de acciones propia (botones de cristal del sistema) va pegada al propio paso, no a la
        // pantalla: con el Duo entreabierto el paso ocupa una mitad y la barra se quedaba cruzando el
        // pliegue y tapando el final del contenido. Aquí reserva su sitio al final del scroll.
        .safeAreaInset(edge: .bottom) {
            if !sideControls {
                bottomActionBar
            }
        }
        .onGeometryChange(for: EdgeInsets.self) { $0.safeAreaInsets } action: { insets = $0 }
        .balancedHorizontalSafeArea()
        // Con el tamaño de la vista, no de la ventana: en el Duo abierto la columna de detalle es
        // estrecha aunque la ventana sea ancha, y con la ventana salían dos columnas apretadas.
        .onGeometryChange(for: CGSize.self) { $0.size } action: { measuredSize = $0 }
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
                            Text(entry.note.isEmpty ? String(localized: "Avance guardado") : entry.note)
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
                            Text(date, format: .relative(presentation: .named))
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
                         text: deadline.formatted(.dateTime.day().month(.abbreviated)),
                         color: MetaTint.date)
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
            withAnimation(.smooth) {
                try? ProgressLog.resolveBlock(for: stepEntity, context: modelContext)
            }
            syncManager?.handleDataChange()
        } label: {
            Text("Ya lo tengo, seguir").frame(maxWidth: .infinity)
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
                    Text("Úsalo cuando ya no te frene: el paso vuelve a «En curso» y tu avance se conserva.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            case .pending, .inProgress:
                // Tres acciones a la vista, una al lado de otra, como controles de Liquid Glass.
                GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    actionTile(String(localized: "Avance"), symbol: Symbols.note, identifier: "step.saveProgress",
                               accessibilityLabel: String(localized: "Guardar avance")) {
                        savingBlocked = false
                        showingSaveProgress = true
                        StepActionsTip().invalidate(reason: .actionPerformed)
                    }
                    actionTile(String(localized: "Atasco"), symbol: "hand.raised", identifier: "step.reportBlock",
                               accessibilityLabel: String(localized: "Me he atascado")) {
                        savingBlocked = true
                        showingSaveProgress = true
                    }
                    actionTile(String(localized: "Completar"), symbol: "checkmark", prominent: true, identifier: "step.toggleCompletion",
                               accessibilityLabel: String(localized: "Marcar como completado")) {
                        withAnimation(.smooth) { toggleStepCompletion() }
                    }
                }
                }
                .popoverTip(StepActionsTip(), arrowEdge: .bottom)
            }
        }
        .controlSize(compactHeight ? .regular : .large)
        .padding(.horizontal, wideLayout ? 0 : 16)
        .padding(.vertical, compactHeight ? 6 : 10)
    }

    /// Pantalla casi cuadrada y pequeña: el iPhone Duo cerrado.
    static func isNearlySquare(_ size: CGSize) -> Bool {
        size.width < 700 && size.height < 760 && size.width / max(size.height, 1) > 0.6
    }

    /// Tamaño de la ventana activa, para decidir la disposición antes de medir.
    static var windowSize: CGSize {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? scenes.first?.windows.first
        return window?.bounds.size ?? .zero
    }

    #if DEBUG
    /// `-StepKitSideControls`: fuerza las acciones en la barra para revisarlas en el simulador.
    static let forcesSideControls = ProcessInfo.processInfo.arguments.contains("-StepKitSideControls")
    #else
    static let forcesSideControls = false
    #endif

    /// Acciones como botones de la barra de herramientas (icono y nombre accesible).
    @ViewBuilder private var sideToolbarActions: some View {
        switch state {
        case .done:
            Button(String(localized: "Marcar como pendiente"), systemImage: "arrow.uturn.backward") {
                withAnimation(.smooth) { toggleStepCompletion() }
            }
            .accessibilityIdentifier("step.toggleCompletion")
        case .blocked:
            Button(String(localized: "Ya lo tengo, seguir"), systemImage: "checkmark.circle") {
                try? ProgressLog.resolveBlock(for: stepEntity, context: modelContext)
                syncManager?.handleDataChange()
            }
            .accessibilityIdentifier("step.resolveBlock")
            Button(String(localized: "Guardar avance"), systemImage: Symbols.note) {
                savingBlocked = false
                showingSaveProgress = true
            }
        case .pending, .inProgress:
            Button {
                savingBlocked = false
                showingSaveProgress = true
            } label: {
                toolbarLabel("Avance", symbol: Symbols.note)
            }
            .accessibilityLabel("Guardar avance")
            .accessibilityIdentifier("step.saveProgress")
            Button {
                savingBlocked = true
                showingSaveProgress = true
            } label: {
                toolbarLabel("Atasco", symbol: "hand.raised")
            }
            .accessibilityLabel("Me he atascado")
            .accessibilityIdentifier("step.reportBlock")
            Button {
                withAnimation(.smooth) { toggleStepCompletion() }
            } label: {
                toolbarLabel("Completar", symbol: "checkmark", primary: true)
                    // El estilo destacado pone el texto en seminegrita y parecía más grande que
                    // «Avance» y «Atasco»: mismo peso; lo distingue el color, no el tamaño.
                    .fontWeight(.regular)
            }
            .buttonStyle(.glassProminent)
            .accessibilityLabel("Marcar como completado")
            .accessibilityIdentifier("step.toggleCompletion")
        }
    }

    /// Barra de acciones propia (iPhone, Duo abierto, iPad): botones de cristal flotando abajo, centrados.
    private var bottomActionBar: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                sideToolbarActions
            }
            .buttonStyle(.glass)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
        .overlay(alignment: .bottom) {
            if let celebration {
                CompletionBanner(celebration: celebration) { openNextStep() }
                    .padding(.bottom, 64)
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    /// Botón de la barra inferior: icono y texto en línea; solo icono cuando la barra va en vertical
    /// (Duo cerrado), donde el texto no cabe. La barra ignora `labelStyle`, de ahí la vista propia.
    /// Cómo van las etiquetas de la barra inferior: 0 solo iconos (vertical), 1 secundarios con icono,
    /// 2 todo con texto. Al girar o plegar cambia, y la barra se rehace entera en vez de transformar
    /// los botones: transformarlos dejaba cápsulas vacías o «Completar» duplicado detrás de «Atasco».
    private var toolbarLabelMode: Int {
        if sideControls { return 0 }
        return layoutSize.width < 500 ? 1 : 2
    }

    @ViewBuilder private func toolbarLabel(_ title: LocalizedStringKey, symbol: String, primary: Bool = false) -> some View {
        // En vertical (Duo cerrado) solo icono; en un iPhone estrecho, texto solo en «Completar»
        // (tres botones con texto no caben y el sistema los plegaba en un menú «…»).
        if sideControls || (!primary && layoutSize.width < 500) {
            Image(systemName: symbol)
        } else {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                Text(title)
            }
        }
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
                Text(weekly ? String(localized: "S\((dates.firstIndex(of: date) ?? 0) + 1)")
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
        .accessibilityValue(done ? String(localized: "Hecha") : String(localized: "Pendiente"))
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
    /// Era el último pendiente: el aviso lleva a la pantalla de Kit completado.
    var kitDone = false
}

/// Confirmación breve y visible al completar: el check se anima y dice qué viene después.
private struct CompletionBanner: View {
    let celebration: Celebration
    let onOpenNext: () -> Void
    @State private var appeared = false

    var body: some View {
        if celebration.nextStepID != nil || celebration.kitDone {
            Button(action: onOpenNext) { content(showsChevron: true) }
                .buttonStyle(.plain)
                .accessibilityHint(celebration.kitDone ? String(localized: "Abre el resumen del Kit completado") : String(localized: "Abre el siguiente paso"))
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
                Text(celebration.kitDone ? String(localized: "¡Kit completado!") : String(localized: "¡Paso completado!")).font(.headline)
                Text(celebration.kitDone ? String(localized: "Era el último paso. Revisa cómo te ha ido.")
                     : celebration.nextTitle.map { String(localized: "Siguiente: \($0)") } ?? String(localized: "Era el último paso del Kit."))
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

/// Lee si la barra de navegación va en vertical (iPhone Duo) y lo comunica; la propiedad de entorno
/// solo existe desde iOS 27.1, por eso va en una vista aparte con disponibilidad propia.
@available(iOS 27.1, *)
private struct ToolbarVerticalEdgeProbe: View {
    @Environment(\.toolbarVerticalEdge) private var edge
    let onChange: (Bool) -> Void

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onChange(of: edge != nil, initial: true) { _, vertical in onChange(vertical) }
    }
}
