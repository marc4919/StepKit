//
//  KitDetailView.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on 13/10/25.
//
//  Refactored by StepKit Refactor.
//

import SwiftUI
import TipKit
import SwiftData

extension View {
    /// Abre los pasos del plan. Va en la raíz de la pila, no en el Kit, para que exista antes que él.
    func stepDestinations() -> some View {
        navigationDestination(for: StepEntity.self) { step in
            StepDetailView(stepEntity: step, stepNumber: step.goal?.position(of: step) ?? 1)
        }
    }
}

struct KitDetailView: View {
    private enum PresentedSheet: String, Identifiable {
        case information
        case annotations

        var id: String { rawValue }
    }

    @Bindable var kitEntity: GoalEntity
    /// Abre la revisión del resultado encima del plan (desde «Por revisar» en Mis Kits).
    var opensResultReview = false
    var onResultReviewOpened: () -> Void = {}
    @State private var showingResultReview = false
    @Environment(\.modelContext) private var modelContext
    @Environment(\.syncManager) private var syncManager
    @Environment(\.apiClient) private var apiClient: any APIClientProtocol
    @Environment(AuthManager.self) private var authManager
    @State private var presentedSheet: PresentedSheet?
    @State private var editingSteps = false
    /// Se reordenó o se quitó un paso de un plan preparado por la IA: se ofrece revisarlo con el asistente.
    @State private var planChangesByHand: String?
    @State private var addingStep = false
    /// Conversación abierta desde el plan: revisar lo cambiado a mano o pedir los pasos de un plan vacío.
    @State private var planConversation: KitConversation?
    @State private var planConversationIntent = AssistantIntent.reviewChanges
    @State private var planFillings = 0
    @State private var isFillingPlan = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var segment = 0
    @State private var headerHeight: CGFloat = 0
    @State private var barTitleShown = false
    /// Tarjeta de una sola vez al abrir el primer Kit: qué es un paso y por dónde empezar.
    @AppStorage("firstKitCardSeen") private var firstKitCardSeen = false
    /// La tarjeta se funde con animación propia; el ajuste guardado se escribe al terminar.
    @State private var firstKitCardDismissed = false
    @State private var wideLayout = false
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var editingEntry: ProgressEntryEntity?
    @Query(sort: \ProgressEntryEntity.notedAt, order: .reverse) private var allEntries: [ProgressEntryEntity]

    private var kitEntries: [ProgressEntryEntity] {
        allEntries.filter { $0.kitID == kitEntity.id && $0.ownerID == kitEntity.ownerID && $0.deletedAt == nil }
    }

    /// En un Kit a mano no hace falta explicar el plan: lo acaba de escribir la propia persona.
    private var showsFirstKitCard: Bool {
        !firstKitCardSeen && !firstKitCardDismissed && !allStepsDone && kitEntity.activeStepCount > 0
            && kitEntity.sourceModel != StepListDraft.manualSource
    }

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                    .id("kit.top")
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { headerHeight = $0 }
                if showsFirstKitCard {
                    firstKitCard
                        .transition(.asymmetric(insertion: .identity,
                                                removal: .opacity.combined(with: .scale(scale: 0.92, anchor: .top))))
                } else if !allStepsDone {
                    TipView(KitAssistantTip())
                    if kitEntity.activeStepCount >= 2 { TipView(EditStepsTip()) }
                }
                if allStepsDone {
                    resultCard
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.9, anchor: .top))
                                .animation(.spring(response: 0.55, dampingFraction: 0.75).delay(0.45)),
                            removal: .opacity))
                }
                if wideLayout {
                    // Pantalla ancha (iPhone Duo abierto, iPad): plan y registro a la vez, sin conmutador.
                    HStack(alignment: .top, spacing: 20) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Plan").font(.title3.bold())
                            stepsSection
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Registro").font(.title3.bold())
                            logSection
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    TipView(KitLogTip())
                    Picker("Vista", selection: $segment) {
                        Text("Plan").tag(0)
                        Text("Registro").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: segment) { _, value in
                        if value == 1 { KitLogTip().invalidate(reason: .actionPerformed) }
                    }
                    .accessibilityIdentifier("kit.segment")
                    if segment == 0 {
                        stepsSection
                    } else {
                        logSection
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 30)
        }
        .balancedHorizontalSafeArea()
        .onGeometryChange(for: Bool.self) { TwoColumnLayout.fits($0.size) } action: { wideLayout = $0 }
        // Los pasos que el asistente acaba de tocar se resaltan unos segundos al verse el plan.
        .onAppear { KitAssistantStore.shared.highlights.fade() }
        .onChange(of: planChangesByHand) { _, changes in
            guard changes != nil else { return }
            withAnimation(.smooth(duration: 0.5)) { proxy.scrollTo("kit.planReview", anchor: .center) }
        }
        .onChange(of: allStepsDone) { _, done in
            guard done else { return }
            // Al completar el último paso: subir arriba y que aparezca el resultado.
            withAnimation(.smooth(duration: 0.5)) { proxy.scrollTo("kit.top", anchor: .top) }
        }
        }
        .background(alignment: .top) { BrandGlow() }
        .background(Color(.systemGroupedBackground))
        // Título vacío hasta que la cabecera se va: un elemento «principal» con opacidad 0 era el
        // «botón fantasma» del Duo cerrado, que coloca ese elemento en una cápsula abajo, al centro.
        .navigationTitle(barTitleShown ? kitEntity.title : "")
        .navigationBarTitleDisplayMode(.inline)
        // El título vive en la cabecera; en la barra solo aparece cuando la cabecera ya no se ve,
        // como en Salud, Fitness o Música. Así no se lee dos veces al entrar.
        .onScrollGeometryChange(for: Bool.self) { $0.contentOffset.y + $0.contentInsets.top > max(headerHeight - 24, 1) } action: { _, past in
            withAnimation(.easeInOut(duration: 0.2)) { barTitleShown = past }
        }
        .toolbar {
            // Asistente primero, como en el paso; lo demás en «···»: con el Duo plegado las barras van en
            // una sola columna y un botón más ya no cabía bien.
            ToolbarItemGroup(placement: .topBarTrailing) {
                NavigationLink {
                    KitAssistantHubView(kit: kitEntity)
                } label: {
                    Label("Asistente", systemImage: Symbols.assistant)
                }
                .badge(pendingProposals)
                .accessibilityIdentifier("kit.assistant")
                .accessibilityValue(pendingProposals == 0 ? "" : pendingProposals == 1 ? String(localized: "Propuesta pendiente") : String(localized: "\(pendingProposals) propuestas pendientes"))
                Menu("Más opciones", systemImage: "ellipsis") {
                    // Con el resultado ya confirmado, el plan es historial: no se edita.
                    if kitEntity.resultConfirmedAt == nil {
                        Button("Editar pasos", systemImage: "list.bullet") {
                            EditStepsTip().invalidate(reason: .actionPerformed)
                            editingSteps = true
                        }
                            .accessibilityIdentifier("kit.editSteps")
                    }
                    Button("Detalles del Kit", systemImage: "info.circle") { presentedSheet = .information }
                        .accessibilityIdentifier("kit.info")
                        .accessibilityHint("Muestra los detalles del Kit y permite editarlos")
                }
                .accessibilityIdentifier("kit.more")
            }
        }
        .navigationDestination(isPresented: $showingResultReview) { ResultReviewView(kit: kitEntity) }
        .onAppear {
            if opensResultReview {
                onResultReviewOpened()
                // Llega con la misma animación que abre el plan; «Volver al plan» será un retroceso normal.
                var instant = Transaction()
                instant.disablesAnimations = true
                withTransaction(instant) { showingResultReview = true }
            }
            ProgressLog.importLegacyKitNotes(for: kitEntity, context: modelContext)
            reactToOverdueSteps()
        }
        .sheet(isPresented: $editingSteps) {
            KitStepsEditorView(kit: kitEntity) { planChanges in
                withAnimation(.smooth) { planChangesByHand = planChanges }
            }
        }
        .sheet(isPresented: $addingStep) { addStepForm }
        .sensoryFeedback(.success, trigger: planFillings)
        .navigationDestination(isPresented: Binding(
            get: { planConversation != nil },
            set: { if !$0 { planConversation = nil } }
        )) {
            if let planConversation {
                planConversationView(planConversation)
            }
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
                                   step: step.map { (kitEntity.position(of: $0), $0.stepTitle) })
        }
    }

    private var logSection: some View {
        KitLogView(kit: kitEntity, entries: kitEntries,
                   onEdit: { editingEntry = $0 },
                   onAddNote: { presentedSheet = .annotations })
    }

    /// Solo la primera vez que se abre un Kit, encima del plan.
    private var firstKitCard: some View {
        PlainCard {
            HStack(alignment: .top, spacing: 12) {
                IconChip(symbol: "hand.wave", color: .accentColor)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tu primer Kit").font(.headline)
                    Text("Cada paso dice qué hacer y qué día toca. Entra en el primero para empezar; puedes guardar avances aunque no lo termines.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Button("Entendido") {
                withAnimation(.smooth(duration: 0.6)) { firstKitCardDismissed = true }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(650))
                    firstKitCardSeen = true
                }
            }
            .buttonStyle(.bordered)
            // Alineado con el texto, no con el icono: 34 pt de chip + 12 de separación.
            .padding(.leading, 46)
            .accessibilityIdentifier("kit.firstKitCard.dismiss")
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
                 text: String(localized: "\(kitEntity.completedStepCount) de \(kitEntity.activeStepCount)"),
                 color: MetaTint.done)
            .accessibilityLabel(String(localized: "\(kitEntity.completedStepCount) de \(kitEntity.activeStepCount) pasos completados"))
        if let date = kitEntity.dueDate {
            MetaChip(symbol: Symbols.wantedDate, text: PlanGrouping.shortDate(date),
                     color: MetaTint.date)
                .accessibilityLabel(String(localized: "Fecha final: \(date.formatted(.dateTime.weekday(.wide).day().month(.wide)))"))
        }
    }

    /// Si un paso se ha quedado atrás, el asistente lo mira una vez al día y propone cómo recolocarlo.
    private func reactToOverdueSteps() {
        let today = Calendar.current.startOfDay(for: .now)
        guard let overdue = kitEntity.orderedActiveSteps.first(where: {
            !$0.isCompleted && ($0.sessionDates.last ?? .distantFuture) < today
        }) else { return }
        let key = "assist.overdue.\(kitEntity.id).\(AssistRequestBuilder.dayFormatter.string(from: today))"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        KitAssistant.react(.overdue, kit: kitEntity, step: overdue, context: modelContext,
                           apiClient: apiClient, token: authManager.token)
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
                    Text(confirmed ? String(localized: "Resultado confirmado") : String(localized: "Has completado todos los pasos"))
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(confirmed ? String(localized: "Ver el resumen de tu recorrido") : String(localized: "Revisa si tienes lo que buscabas"))
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

    /// Propuestas pendientes en todas las conversaciones del Kit (la insignia muestra cuántas).
    private var pendingProposals: Int {
        KitAssistantStore.shared.conversations(for: kitEntity.id).reduce(0) { $0 + $1.pendingProposalCount }
    }

    // MARK: - Plan

    /// Cabeceras de sección por semana (por día si el Kit cabe en dos semanas), como las listas agrupadas
    /// de iOS, con la regla que comparte con la vista previa al crear (`PlanGrouping`).
    private func planConversationView(_ conversation: KitConversation) -> KitAssistantChatView {
        var onAccept: ((PlanProposal) -> Void)?
        if planConversationIntent.id == AssistantIntent.suggestSteps.id {
            onAccept = { proposal in fillPlan(proposal) }
        }
        return KitAssistantChatView(kit: kitEntity, conversation: conversation, initialIntent: planConversationIntent.id,
                                    onAcceptOnPlan: onAccept)
    }

    private var addStepForm: some View {
        StepDraftFormView(step: StepDraft(minutes: ManualKit.stepMinutes(for: kitEntity), date: nil),
                          dateIsOptional: true, unsetDateNote: "Sin fecha, se reparte hasta la fecha final.",
                          earliest: ManualKit.lastFixedDate(of: kitEntity), latestDate: kitEntity.targetDate) { step in
            withAnimation(.smooth) {
                _ = ManualKit.addStep(step.normalized, to: kitEntity, context: modelContext)
            }
            try? modelContext.save()
            syncManager?.handleDataChange()
            NotificationService.shared.refreshStepReminders()
        }
    }

    /// En un Kit a mano, añadir pasos es lo principal: va en el plan y no escondido en «···».
    private var showsAddStepRow: Bool {
        kitEntity.sourceModel == StepListDraft.manualSource && kitEntity.resultConfirmedAt == nil
            && kitEntity.activeStepCount < StepListEditor.maxSteps
    }

    private func openPlanConversation(_ intent: AssistantIntent) {
        planConversationIntent = intent
        let conversation = KitAssistantStore.shared.newConversation(kit: kitEntity, title: intent.title)
        conversation.planChanges = planChangesByHand
        withAnimation(.smooth) { planChangesByHand = nil }
        planConversation = conversation
    }

    /// Los pasos aceptados entran en el plan a la vista, de uno en uno, y una vibración marca el final.
    private func fillPlan(_ proposal: PlanProposal) {
        Task { @MainActor in
            // Tras volver al plan: antes la animación ocurriría detrás de la conversación.
            try? await Task.sleep(for: .milliseconds(500))
            isFillingPlan = true
            await proposal.accept(in: kitEntity, context: modelContext, highlights: KitAssistantStore.shared.highlights,
                                  pause: reduceMotion ? .zero : .milliseconds(180),
                                  animation: reduceMotion ? nil : .smooth(duration: 0.35))
            KitAssistantChatView.record(proposal, kit: kitEntity, context: modelContext, syncManager: syncManager)
            withAnimation(.smooth) { isFillingPlan = false }
            planFillings += 1
        }
    }

    /// Tras reordenar, añadir o quitar pasos de un plan preparado. Una tarjeta y no un aviso: es una
    /// sugerencia, y no debe interrumpir.
    private var planReviewCard: some View {
        TintCard(strength: 0.10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Has cambiado el plan").font(.headline)
                Text("El asistente puede comprobar que sigue teniendo sentido. Lo que proponga podrás aceptarlo o descartarlo.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 10) {
                Button("Revisar") { openPlanConversation(.reviewChanges) }
                    .buttonStyle(.borderedProminent)
                    .tint(.primaryAction)
                    .accessibilityIdentifier("kit.planReview")
                Button("Ahora no") { withAnimation(.smooth) { planChangesByHand = nil } }
                    .buttonStyle(.bordered)
            }
        }
        .id("kit.planReview")
        .transition(.opacity)
    }

    private var addStepRow: some View {
        Button {
            addingStep = true
        } label: {
            Label { Text("Añadir paso") } icon: { Image(systemName: "plus.circle.fill") }
                .font(.body.weight(.medium))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.tint)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18))
        .accessibilityIdentifier("kit.addStep")
    }

    private var stepsSection: some View {
        Group {
            if planChangesByHand != nil {
                planReviewCard
            }
            if kitEntity.orderedActiveSteps.isEmpty {
                emptyStepsView
            } else {
                let steps = Array(kitEntity.orderedActiveSteps.enumerated())
                let groups = PlanGrouping.groups(steps) { $0.element.suggestedDeadline }
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(groups, id: \.key) { group in
                        VStack(alignment: .leading, spacing: 6) {
                            if !group.title.isEmpty {
                                Text(group.title)
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)
                                    .padding(.leading, 12)
                                    .accessibilityAddTraits(.isHeader)
                            }
                            VStack(spacing: 0) {
                                ForEach(group.items, id: \.element.id) { index, step in
                                    PlanStepRow(step: step, number: index + 1,
                                                state: step.progressState(hasEntries: kitEntries.contains { $0.stepID == step.id }),
                                                showsDate: !group.byDay) {
                                        withAnimation(.snappy) {
                                            try? ProgressLog.toggleCompletion(of: step, context: modelContext)
                                        }
                                        syncManager?.handleDataChange()
                                    }
                                    if step.id != group.items.last?.element.id {
                                        Divider().padding(.leading, 52)
                                    }
                                }
                            }
                            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18))
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    // Fuera mientras entran los pasos: si no, va saltando entre ellos.
                    if showsAddStepRow && !isFillingPlan {
                        addStepRow
                            .transition(.opacity)
                    }
                }
            }
        }
    }

    // MARK: - Empty Steps View
    /// Guía lo siguiente que hacer. Un Kit generado no debería quedar vacío, pero si queda, sirve igual.
    private var emptyStepsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 36))
                .foregroundStyle(LinearGradient.accentWithOpacity( 0.6))
                .accessibilityHidden(true)

            Text("Aún no hay pasos")
                .font(.headline)
            Button {
                addingStep = true
            } label: {
                Text("Crear el primer paso").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.primaryAction)
            .controlSize(.large)
            .accessibilityIdentifier("kit.firstStep")
            Button {
                openPlanConversation(.suggestSteps)
            } label: {
                Text("Pedir pasos al asistente").frame(minHeight: 44)
            }
            .font(.subheadline.weight(.semibold))
            .accessibilityIdentifier("kit.askSteps")
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18))
    }
}

// MARK: - Fila del plan

private struct PlanStepRow: View {
    let step: StepEntity
    let number: Int
    let state: StepProgressState
    /// En las secciones por semana cada fila lleva su día; en las diarias lo dice la cabecera.
    let showsDate: Bool

    /// Una línea gris con el día («Hoy» en el color de la app), los minutos y la repetición abreviada.
    /// Sin chips ni etiqueta «En curso»: el estado ya lo dice el icono.
    private var meta: Text {
        var parts: [Text] = []
        if showsDate, let date = step.suggestedDeadline {
            if step.isCompleted {
                // Un paso hecho no «toca mañana»: su día, sin más.
                parts.append(Text(date.formatted(.dateTime.weekday(.abbreviated).day())))
            } else {
                let day = PlanGrouping.rowDate(date)
                parts.append(day.isToday ? Text(day.text).foregroundStyle(.tint).fontWeight(.semibold) : Text(day.text))
            }
        }
        parts.append(Text(String(localized: "\(step.estimateMinutes) min")))
        if let repetition = step.repetition {
            parts.append(Text(repetition.shortLabel))
        }
        return parts.dropFirst().reduce(parts[0]) { $0 + Text(" · ") + $1 }
    }

    let onToggle: () -> Void

    /// Lo que el asistente acaba de hacerle a este paso, mientras el plan lo resalta.
    private var highlight: ChangeHighlights.Kind? { KitAssistantStore.shared.highlights.kind(for: step.id) }

    private var highlightLabel: String {
        switch highlight {
        case .edited: String(localized: "Editado")
        case .added: String(localized: "Nuevo")
        case .moved: String(localized: "Movido")
        case .blocked: String(localized: "En pausa")
        case nil: ""
        }
    }

    private var highlightColor: Color { highlight == .blocked ? .red : .accentColor }

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
            .accessibilityLabel(step.isCompleted ? String(localized: "Marcar como pendiente") : String(localized: "Marcar como completado"))
            .accessibilityValue(String(localized: "Paso \(number): \(step.stepTitle)"))
            .accessibilityIdentifier("step.rowToggle")
            NavigationLink(value: step) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(step.stepTitle)
                            .foregroundStyle(state == .done ? .secondary : .primary)
                            .strikethrough(state == .done, color: .secondary)
                            .multilineTextAlignment(.leading)
                        HStack(spacing: 8) {
                            meta
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            // Recién tocado por el asistente: solo una chip junto al tiempo, unos
                            // segundos, que se apaga sola (ver ChangeHighlights.fade). Sin tintar la fila.
                            if highlight != nil {
                                Text(highlightLabel)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(highlightColor)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(highlightColor.opacity(0.14), in: .capsule)
                                    .transition(.opacity)
                            }
                            if state == .blocked {
                                Text(state.label)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.red)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.red.opacity(0.14), in: .capsule)
                            }
                        }
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
            .accessibilityLabel(String(localized: "Paso \(number): \(step.stepTitle). \(state.label)"))
            .accessibilityValue(step.suggestedDeadline.map { $0.formatted(.dateTime.weekday(.wide).day().month(.wide)) } ?? "")
            .accessibilityHint("Toca dos veces para abrir los detalles del paso")
            .accessibilityIdentifier("step.row")
        }
        .animation(.easeInOut(duration: 0.6), value: highlight)
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
        risks: [String(localized: "Falta de tiempo"), String(localized: "Curva de aprendizaje")]
    )
    container.mainContext.insert(kitEntity)

    return NavigationStack {
        KitDetailView(kitEntity: kitEntity).stepDestinations()
    }
    .modelContainer(container)
}
