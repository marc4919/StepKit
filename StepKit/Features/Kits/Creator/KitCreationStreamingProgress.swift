//
//  KitCreationStreamingProgress.swift
//  StepKit
//
//  Crear Kit v4.4: «Dando forma a tu Kit» mientras llegan los pasos y, al
//  terminar, «Tu plan» para revisarlo antes de aceptarlo.
//

import SwiftUI

struct KitCreationStreamingProgress: View {
    @Binding var streamingState: KitStreamingState
    let onSave: () -> Void
    let onDiscard: () -> Void
    /// Kit delicado: respuestas a las preguntas del servidor o seguir sin responder.
    var onAnswer: ([KitAnswer]) -> Void = { _ in }
    var onSkipQuestions: () -> Void = {}
    @State private var shownProgress: Double = 0
    /// Se pasa a «Tu plan» cuando la barra y el recorrido han terminado de verse.
    @State private var showReview = false
    @State private var reviewMounted = false
    @State private var liftOff = false
    @State private var stepsChecked = false
    /// Cuándo empezó la preparación: pasado un rato se explica qué se está haciendo.
    @State private var preparingSince = Date.now
    /// Pasos abiertos en la revisión para ver qué incluyen antes de crear el Kit.
    @State private var expandedSteps: Set<Int> = []
    @State private var reviewChecked = false
    @State private var finalFill = false
    /// Pantalla de cuidado: visible desde plan_mode «careful» hasta que llega el título (mínimo ~1 s).
    @State private var showCareful = false
    /// Transición a «Tu plan»: la esfera viaja a su sitio, se dibuja el anillo y aparece el resto.
    @Namespace private var sphereSpace
    @State private var sphereInFlight = false
    @State private var sphereLanded = false
    @State private var ringDrawn: CGFloat = 0
    @State private var contentRevealed = false
    @State private var carefulShownAt: Date?
    /// Las preguntas entran después de que el aviso de cuidado se haya visto con calma.
    @State private var questionsVisible = false
    @State private var reviewWide = false
    @State private var preparingSize: CGSize = .zero
    private var preparingSideBySide: Bool { preparingSize.width >= 760 && preparingSize.width > preparingSize.height }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Progreso de la preparación: arranque, resultado recibido y pasos llegando.
    private var targetProgress: Double {
        if finalFill { return 1 }
        if streamingState.isComplete { return 0.95 }
        guard streamingState.kitTitle != nil else { return 0.08 }
        let received = Double(streamingState.steps.count)
        if let total = streamingState.totalSteps, total > 0 {
            return 0.15 + 0.75 * received / Double(total)
        }
        // Sin total (el servidor ya no lo anuncia): cada paso acerca la barra, sin llegar al final.
        // Curva suave: cada paso suma algo parecido durante todo el plan (5 pasos ≈ 50 %, 10 ≈ 72 %).
        return 0.15 + 0.75 * (1 - pow(0.88, received))
    }

    var body: some View {
        ZStack {
            Group {
                if streamingState.hasError {
                    errorView
                } else {
                    // La revisión se monta oculta antes del vuelo de la esfera: así su maquetación no
                    // coincide con el primer fotograma de la animación (evita el tirón al arrancar).
                    if reviewMounted {
                        reviewView
                            .opacity(showReview ? 1 : 0)
                            .allowsHitTesting(showReview)
                            .accessibilityHidden(!showReview)
                    }
                    if !showReview {
                        preparingView
                            .transition(.opacity)
                    }
                }
            }
            if sphereInFlight && !sphereLanded {
                // La misma esfera pasa del centro de la preparación al anillo de «Tu plan».
                GeometryReader { geo in
                    BrandSphere(size: min(geo.size.width, geo.size.height), glow: false)
                        .frame(width: geo.size.width, height: geo.size.height)
                }
                .matchedGeometryEffect(id: "sphere", in: sphereSpace, properties: .frame, isSource: false)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
        .onChange(of: streamingState.isComplete) { _, complete in
            if complete { scheduleReview() }
        }
        // En cuanto llega el primer paso, la revisión se monta oculta: su coste no coincide con ninguna animación.
        .onChange(of: streamingState.steps.isEmpty) { _, empty in
            if !empty, !streamingState.isRestarting { reviewMounted = true }
        }
        .onChange(of: streamingState.isRestarting) { _, restarting in
            if restarting { reviewMounted = false }
        }
        .onAppear {
            if streamingState.isComplete { scheduleReview() }
        }
    }

    // MARK: - Preparando

    private var preparingView: some View {
        Group {
            if preparingSideBySide {
                // Pantalla ancha y baja (iPhone Duo abierto en horizontal): la esfera crece a la izquierda,
                // centrada en vertical, y a la derecha el texto, las fases y la barra.
                HStack(spacing: 24) {
                    // Con preguntas, la esfera cede sitio: las preguntas necesitan más ancho.
                    preparingOrbit
                        .frame(maxWidth: questionsVisible ? 220 : .infinity, maxHeight: .infinity)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 22) {
                            preparingContent
                        }
                        .padding(.vertical)
                        .frame(minHeight: preparingSize.height, alignment: .center)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 24)
                .balancedHorizontalSafeArea()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        preparingOrbit
                        preparingContent
                    }
                    .padding(.vertical)
                }
            }
        }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { preparingSize = $0 }
        .background { EntryBackground() }
        // Hápticos sutiles: un toque ligero por cada check y éxito al despegar.
        .sensoryFeedback(.impact(weight: .light), trigger: streamingState.kitTitle != nil)
        .sensoryFeedback(.impact(weight: .light), trigger: stepsChecked)
        .sensoryFeedback(.impact(weight: .light), trigger: reviewChecked)
        .sensoryFeedback(.success, trigger: liftOff)
        .onAppear {
            advance(to: targetProgress)
            if streamingState.isCareful { presentCareful() }
        }
        .onChange(of: targetProgress) { _, value in advance(to: value) }
        .onChange(of: streamingState.isCareful) { _, careful in
            if careful { presentCareful() }
        }
        .onChange(of: streamingState.pendingQuestions.isEmpty) { _, empty in
            if empty {
                withAnimation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.88)) {
                    questionsVisible = false
                }
            } else {
                Task { await revealQuestions() }
            }
        }
        .onChange(of: streamingState.isRestarting) { _, restarting in
            guard restarting else { return }
            // El plan se rehace: la barra y la esfera vuelven atrás con calma, sin saltos.
            let rewind = min(shownProgress, 0.18)
            if reduceMotion {
                shownProgress = rewind
            } else {
                withAnimation(.smooth(duration: 1.2)) { shownProgress = rewind }
            }
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.6), value: streamingState.isRestarting)
        .task {
            // Avance continuo mientras se espera el siguiente evento: se frena al acercarse al
            // siguiente tramo pero nunca se queda quieto (en el modo cuidado la espera es larga).
            while !Task.isCancelled && !finalFill {
                try? await Task.sleep(for: .milliseconds(450))
                guard streamingState.pendingQuestions.isEmpty else { continue }
                let ceiling = min(0.9, targetProgress + 0.06)
                if shownProgress < ceiling {
                    let step = max(0.002, (ceiling - shownProgress) * 0.05)
                    advance(to: min(ceiling, shownProgress + step), duration: 0.45)
                }
            }
        }
    }

    @ViewBuilder private var preparingOrbit: some View {
        // La esfera se forma mientras avanza la barra y, al terminar, despega.
        OrbitMark(height: preparingSideBySide ? min(320, preparingSize.height * 0.55) : (questionsVisible ? 120 : 190), buildProgress: shownProgress, liftOff: liftOff, hidesSphere: sphereInFlight)
            .background {
                if showCareful && !sphereInFlight {
                    CarefulHalo(diameter: 59 * (0.15 + 0.85 * shownProgress))
                }
            }
            .overlay {
                // Hueco de la esfera (190 × 0,31): de aquí sale hacia «Tu plan».
                Color.clear
                    .frame(width: 59, height: 59)
                    .matchedGeometryEffect(id: "sphere", in: sphereSpace, isSource: !showReview)
            }
            .padding(.horizontal, 20)
    }

    @ViewBuilder private var preparingContent: some View {
        ZStack {
            Text(headline)
                .font(.title.bold())
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .id(headline)
                .transition(Self.swap)
        }
        .accessibilityAddTraits(.updatesFrequently)
        if streamingState.isRestarting {
            Text("Lo estoy rehaciendo para que encaje mejor con tu tiempo.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 30)
                .transition(Self.swap)
        }
        if questionsVisible {
            // Los motivos quedan como recordatorio compacto encima de las preguntas.
            CarefulReasonChips(reasons: streamingState.carefulReasons)
                .padding(.horizontal, 24)
                .transition(.asymmetric(
                    insertion: .opacity.animation(.easeOut(duration: 0.35).delay(0.3)),
                    removal: .opacity))
            KitQuestionsCard(questions: streamingState.pendingQuestions,
                             onSubmit: onAnswer, onSkip: onSkipQuestions)
                .padding(.horizontal, 24)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .offset(y: 40)),
                    removal: .opacity))
        } else {
            preparingDetails
                .transition(.asymmetric(
                    insertion: .opacity.animation(.easeOut(duration: 0.4).delay(0.2)),
                    removal: .opacity.combined(with: .scale(scale: 0.97, anchor: .top))))
        }
        Text("Puedes cancelar: tu idea se conserva en el formulario.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    private func scheduleReview() {
        Task {
            guard !reduceMotion else {
                reviewMounted = true
                stepsChecked = true
                finalFill = true
                shownProgress = 1
                reviewChecked = true
                showReview = true
                sphereLanded = true
                ringDrawn = 1
                contentRevealed = true
                return
            }
            if !reviewMounted {
                reviewMounted = true
                try? await Task.sleep(for: .milliseconds(150))
            }
            // Primero se completan los checks y la barra; luego la esfera viaja al anillo de
            // «Tu plan», el anillo se dibuja a su alrededor y el resto aparece en cascada.
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { stepsChecked = true }
            try? await Task.sleep(for: .milliseconds(500))
            finalFill = true
            advance(to: 1, duration: 1.0)
            try? await Task.sleep(for: .milliseconds(750))
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { reviewChecked = true }
            try? await Task.sleep(for: .milliseconds(650))
            // Relevo sin animación: la esfera de vuelo aparece justo donde estaba la otra.
            sphereInFlight = true
            try? await Task.sleep(for: .milliseconds(40))
            withAnimation(.spring(response: 0.8, dampingFraction: 0.86)) { showReview = true }
            try? await Task.sleep(for: .milliseconds(820))
            sphereLanded = true
            withAnimation(.easeInOut(duration: 0.7)) { ringDrawn = 1 }
            try? await Task.sleep(for: .milliseconds(300))
            contentRevealed = true
        }
    }

    /// Motivos del cuidado, fases y barra mientras se prepara el plan.
    @ViewBuilder private var preparingDetails: some View {
                if showCareful {
                    // En modo cuidado los motivos acompañan toda la preparación, encima de las fases.
                    CarefulReasonsList(reasons: streamingState.carefulReasons)
                        .padding(.horizontal, 24)
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                }
                VStack(alignment: .leading, spacing: 16) {
                    phase(done: streamingState.kitTitle != nil, active: streamingState.kitTitle == nil,
                          title: String(localized: "Tu objetivo"),
                          detail: streamingState.isRestarting ? String(localized: "Ajustando")
                            : streamingState.kitTitle == nil ? String(localized: "Preparando") : String(localized: "Listo"))
                    phase(done: stepsChecked,
                          active: streamingState.kitTitle != nil && !stepsChecked,
                          title: String(localized: "Pasos del plan"), detail: stepsDetail)
                    phase(done: reviewChecked, active: stepsChecked && !reviewChecked,
                          title: String(localized: "Plan listo para revisar"),
                          detail: reviewChecked ? String(localized: "Listo") : String(localized: "Lo revisarás tú antes de empezar"))
                }
                .opacity(streamingState.isRestarting ? 0.45 : 1)
                .padding(.horizontal, 30)
                SmoothProgressBar(value: shownProgress)
                    .padding(.horizontal, 30)
                    .accessibilityElement()
                    .accessibilityLabel("Progreso del plan")
                    .accessibilityValue(Text(shownProgress, format: .percent.precision(.fractionLength(0))))
                WaitingHints(since: preparingSince, active: !reviewChecked && !streamingState.isRestarting && !questionsVisible)
                    .padding(.horizontal, 30)
    }

    /// Si el plan tarda (planes largos, red lenta), frases que cuentan qué se hace, para que no parezca parado.
    private struct WaitingHints: View {
        let since: Date
        let active: Bool
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        private static let hints = [
            String(localized: "Los planes con más pasos tardan un poco más."),
            String(localized: "Repartiendo los pasos hasta tu fecha…"),
            String(localized: "Comprobando que cada paso quepa en tu tiempo…"),
            String(localized: "Escribiendo qué hacer en cada paso…"),
        ]

        var body: some View {
            TimelineView(.periodic(from: since, by: 1)) { context in
                let elapsed = context.date.timeIntervalSince(since)
                let hint = active && elapsed >= 10 ? Self.hints[Int((elapsed - 10) / 4) % Self.hints.count] : nil
                Text(hint ?? " ")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id(hint)
                    .transition(.opacity)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.4), value: hint)
                    .accessibilityHidden(hint == nil)
            }
        }
    }

    /// Relevo de textos sin solaparse: lo anterior se va antes de que llegue lo nuevo.
    private static let swap: AnyTransition = .asymmetric(
        insertion: .opacity.animation(.easeOut(duration: 0.35).delay(0.25)),
        removal: .opacity.animation(.easeIn(duration: 0.2))
    )

    private var headline: String {
        if streamingState.isRestarting { return String(localized: "Ajustando tu plan…") }
        if questionsVisible { return String(localized: "Antes de prepararlo, cuéntame un poco más") }
        if showCareful { return String(localized: "Preparando tu plan con más cuidado") }
        return String(localized: "Dando forma a tu Kit")
    }

    /// El aviso de cuidado se ve al menos ~2,5 s (los motivos entran y se leen) y luego
    /// se recoge hacia arriba para dar paso a las preguntas.
    private func revealQuestions() async {
        // Solo se espera si hay aviso de cuidado que leer; con un objetivo ambiguo (modo normal)
        // las preguntas salen enseguida.
        if !reduceMotion, let carefulShownAt {
            let shown = Date.now.timeIntervalSince(carefulShownAt)
            if shown < 2.5 { try? await Task.sleep(for: .seconds(2.5 - shown)) }
        }
        guard !streamingState.pendingQuestions.isEmpty else { return }
        withAnimation(reduceMotion ? nil : .spring(response: 0.7, dampingFraction: 0.86)) {
            questionsVisible = true
        }
    }

    private func presentCareful() {
        carefulShownAt = .now
        if reduceMotion {
            showCareful = true
        } else {
            withAnimation(.easeInOut(duration: 0.4)) { showCareful = true }
        }
    }

    private func advance(to value: Double, duration: Double = 0.9) {
        guard value > shownProgress else { return }
        if reduceMotion {
            shownProgress = value
        } else {
            withAnimation(.smooth(duration: duration)) { shownProgress = value }
        }
    }

    /// «lun, 3 nov» a partir de la fecha del servidor (yyyy-MM-dd).
    private static func stepDate(_ text: String) -> Date? {
        let parser = DateFormatter()
        parser.calendar = Calendar(identifier: .gregorian)
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"
        return parser.date(from: text)
    }

    private var stepsDetail: String {
        if let total = streamingState.totalSteps {
            return String(localized: "\(streamingState.steps.count) de \(total) listos")
        }
        if !streamingState.steps.isEmpty {
            return streamingState.steps.count == 1 ? String(localized: "1 paso listo") : String(localized: "\(streamingState.steps.count) pasos listos")
        }
        return streamingState.kitTitle == nil ? String(localized: "Pendiente") : String(localized: "Preparando")
    }

    private func phase(done: Bool, active: Bool, title: String, detail: String) -> some View {
        HStack(spacing: 14) {
            // Tres símbolos superpuestos que se funden, en vez de reemplazar uno por otro: el reemplazo
            // de símbolos, con el pulso activo a la vez, dejaba ver el check un instante antes de tiempo.
            ZStack {
                Image(systemName: "circle")
                    .foregroundStyle(Color.secondary)
                    .opacity(done || active ? 0 : 1)
                Image(systemName: "circle.dotted")
                    .foregroundStyle(Color.accentColor)
                    .symbolEffect(.pulse, isActive: active && !done)
                    .opacity(active && !done ? 1 : 0)
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.green)
                    .opacity(done ? 1 : 0)
                    .scaleEffect(done ? 1 : 0.6)
            }
            .font(.title2)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: done)
            .animation(.easeInOut(duration: 0.25), value: active)
            VStack(alignment: .leading) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Revisar el plan

    private var reviewView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if reviewWide {
                    // Pantalla ancha (iPhone Duo abierto, iPad): resumen a la izquierda, «A tener en cuenta» a la derecha.
                    reviewHeader
                    // Izquierda: meta y primer paso. Derecha: «A tener en cuenta», la nota y los botones,
                    // siempre a la vista sin tapar la lista de pasos.
                    HStack(alignment: .top, spacing: 24) {
                        VStack(alignment: .leading, spacing: 18) {
                            reviewKPI
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        VStack(alignment: .leading, spacing: 18) {
                            reviewRisks
                            reviewNote
                            reviewActions
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    // Los pasos, debajo y a todo lo ancho.
                    reviewStepsList
                } else {
                    reviewHeader
                    reviewKPI
                    reviewNote
                    reviewStepsList
                    reviewRisks
                }
            }
            .padding()
        }
        .balancedHorizontalSafeArea()
        .onGeometryChange(for: Bool.self) { TwoColumnLayout.fits($0.size) } action: { reviewWide = $0 }
        .background(alignment: .top) { BrandGlow() }
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) {
            if !reviewWide {
                reviewActions
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .background(.bar)
            }
        }
    }

    private var reviewActions: some View {
        VStack(spacing: 8) {
            Button(action: onSave) {
                Label("Aceptar y empezar", systemImage: "chevron.right")
                    .labelStyle(TrailingIconLabelStyle())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("kitCreator.save")
            Button("Descartar y volver a mi idea", role: .destructive, action: onDiscard)
                .font(.subheadline)
                .accessibilityIdentifier("kitCreator.discard")
        }
        .controlSize(.large)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
        .modifier(Reveal(shown: contentRevealed, order: 3))
    }

    @ViewBuilder private var reviewHeader: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .trim(from: 0, to: ringDrawn)
                    .stroke(Color.accentColor.opacity(0.25),
                            style: StrokeStyle(lineWidth: 70 * 0.11, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Color.clear
                    .frame(width: 34, height: 34)
                    .matchedGeometryEffect(id: "sphere", in: sphereSpace, isSource: showReview)
                if sphereLanded {
                    BrandSphere(size: 34, glow: false)
                }
            }
            .frame(width: 70, height: 70)
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(streamingState.kitTitle ?? String(localized: "Tu plan"))
                    .font(.title2.bold())
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    MetaChip(symbol: "list.bullet", text: String(localized: "\(streamingState.steps.count) pasos"), color: .accentColor)
                    // Un plan para hoy no tiene horizonte que mostrar.
                    if let days = streamingState.horizonDays, days > 0 {
                        MetaChip(symbol: Symbols.wantedDate,
                                 text: days == 1 ? String(localized: "1 día") : String(localized: "\(days) días"),
                                 color: MetaTint.date)
                    }
                }
            }
            .modifier(Reveal(shown: contentRevealed, order: 0))
        }
    }

    @ViewBuilder private var reviewKPI: some View {
        if let kpi = streamingState.kpi, !kpi.isEmpty {
            PlainCard {
                Eyebrow(text: String(localized: "Resultado"), color: .secondary)
                Text(kpi)
            }
            .modifier(Reveal(shown: contentRevealed, order: 1))
        }
    }

    @ViewBuilder private var reviewNote: some View {
        Text("Revisa el plan antes de empezar. Podrás editar los pasos después.")
            .foregroundStyle(.secondary)
            .modifier(Reveal(shown: contentRevealed, order: 2))
    }

    /// Arriba, el total (pasos, semanas y horas con las repeticiones); debajo, las mismas cabeceras por
    /// semana que el plan del Kit (`PlanGrouping`) y filas con título, día y repetición abreviada. Los
    /// minutos de cada paso están en su detalle desplegable.
    @ViewBuilder private var reviewStepsList: some View {
        let steps = Array(streamingState.steps.enumerated())
        let groups = PlanGrouping.groups(steps) { Self.stepDate($0.element.suggestedDeadline) }
        VStack(alignment: .leading, spacing: 14) {
            Text(PlanGrouping.summary(
                stepCount: steps.count,
                dates: steps.compactMap { Self.stepDate($0.element.suggestedDeadline) },
                totalMinutes: steps.reduce(0) { $0 + $1.element.estimateMinutes * ($1.element.repetition?.repetition?.times ?? 1) }))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("review.summary")
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
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(group.items, id: \.offset) { index, step in
                            reviewStepRow(index: index, step: step, showsDate: !group.byDay)
                            if index != group.items.last?.offset {
                                Divider().padding(.leading, 52)
                            }
                        }
                    }
                    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18))
                }
            }
        }
        .modifier(Reveal(shown: contentRevealed, order: 4))
    }

    private func reviewStepRow(index: Int, step: StreamStepOutput, showsDate: Bool) -> some View {
        Button {
            withAnimation(.smooth(duration: 0.3)) {
                if expandedSteps.contains(index) { expandedSteps.remove(index) } else { expandedSteps.insert(index) }
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Text("\(index + 1)")
                    .font(.subheadline.bold().monospacedDigit())
                    .foregroundStyle(.tint)
                    .frame(width: 28, height: 28)
                    .background(Color.accentColor.opacity(0.12), in: .circle)
                VStack(alignment: .leading, spacing: 3) {
                    Text(step.stepTitle)
                    if let meta = reviewMeta(step, showsDate: showsDate) {
                        meta
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if expandedSteps.contains(index) {
                        // Resumen: qué queda hecho, el tiempo, el esfuerzo y el principio de la descripción.
                        VStack(alignment: .leading, spacing: 6) {
                            if !step.description.short.isEmpty {
                                Text("Al terminar").font(.caption.weight(.semibold))
                                Text(step.description.short).font(.subheadline)
                            }
                            Label(String(localized: "\(step.estimateMinutes) min"), systemImage: Symbols.time)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(MetaTint.time)
                            Label(String(localized: "Esfuerzo \(StepDetailHelpers.effortLevelText(for: step.effortLevel).lowercased())"),
                                  systemImage: Symbols.effort)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(MetaTint.effort)
                            if !step.description.long.isEmpty {
                                Text(step.description.long)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                            }
                        }
                        .padding(.top, 6)
                        // La fila crece y el texto se funde dentro de ella: nada se desliza desde fuera.
                        .transition(.asymmetric(
                            insertion: .opacity.animation(.easeOut(duration: 0.25).delay(0.12)),
                            removal: .opacity.animation(.easeIn(duration: 0.12))))
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.down")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(expandedSteps.contains(index) ? 180 : 0))
                    .padding(.top, 6)
            }
            .padding(12)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(expandedSteps.contains(index) ? String(localized: "Oculta el detalle del paso") : String(localized: "Muestra el detalle del paso"))
    }

    /// «Hoy · cada día, 3 días» o «mié 4»; nada en un grupo diario sin repetición.
    private func reviewMeta(_ step: StreamStepOutput, showsDate: Bool) -> Text? {
        var parts: [Text] = []
        if showsDate, let date = Self.stepDate(step.suggestedDeadline) {
            let day = PlanGrouping.rowDate(date)
            parts.append(day.isToday ? Text(day.text).foregroundStyle(.tint).fontWeight(.semibold) : Text(day.text))
        }
        if let repetition = step.repetition?.repetition {
            parts.append(Text(repetition.shortLabel))
        }
        guard let first = parts.first else { return nil }
        return parts.dropFirst().reduce(first) { $0 + Text(" · ") + $1 }
    }

    @ViewBuilder private var reviewRisks: some View {
        if !streamingState.risks.isEmpty {
            PlainCard {
                Eyebrow(text: String(localized: "A tener en cuenta"), color: .secondary)
                ForEach(streamingState.risks, id: \.self) { risk in
                    let topic = RiskTopic(risk)
                    Label {
                        Text(risk).foregroundStyle(.secondary)
                    } icon: {
                        Image(systemName: topic.symbol).foregroundStyle(topic.tint)
                    }
                }
            }
            .modifier(Reveal(shown: contentRevealed, order: 5))
        }
    }

    // MARK: - Error

    private var errorView: some View {
        ScrollView {
            VStack(spacing: 18) {
                ZStack(alignment: .topTrailing) {
                    OrbitMark(height: 180)
                    Image(systemName: "wifi.exclamationmark")
                        .font(.title3.bold())
                        .foregroundStyle(.orange)
                        .frame(width: 44, height: 44)
                        .background(.orange.opacity(0.15), in: .circle)
                        .offset(x: -60, y: 10)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 30)
                Text("Tu idea sigue aquí")
                    .font(.largeTitle.bold())
                Text(streamingState.error ?? String(localized: "No se pudo preparar el plan."))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button(action: onDiscard) {
                    Text("Volver a mi idea").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal)
                .padding(.top, 8)
                Text("Lo que escribiste se conserva en el formulario.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
    }
}

/// Barra de progreso suave con degradado de la marca y brillo que recorre la parte completada.
/// Aparición en cascada de «Tu plan» tras dibujarse el anillo.
private struct Reveal: ViewModifier {
    let shown: Bool
    let order: Int

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 14)
            .animation(.smooth(duration: 0.5).delay(Double(order) * 0.08), value: shown)
    }
}

/// Motivos del modo cuidado. Sin colores de alarma: es acompañar, no juzgar.
private struct CarefulReasonsList: View {
    let reasons: [String]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    static let texts: [String: (text: String, symbol: String)] = [
        "health": (String(localized: "Afecta a tu salud"), "heart"),
        "mental_health": (String(localized: "Cuida tu bienestar emocional"), "leaf"),
        "substances": (String(localized: "Implica dejar o reducir una sustancia"), "hand.raised"),
        "disability": (String(localized: "Adaptado a tu situación"), "figure.roll"),
        "financial_risk": (String(localized: "Hay dinero en juego"), "eurosign.circle"),
        "legal": (String(localized: "Buscamos una alternativa legal"), "checkmark.shield"),
        "tight_deadline": (String(localized: "El plazo es muy corto"), "clock"),
        "safety": (String(localized: "Hay que hacerlo con seguridad"), "exclamationmark.shield")
    ]

    private var items: [(text: String, symbol: String)] {
        reasons.compactMap { Self.texts[$0] }
    }


    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Me tomo unos segundos más para que el plan te cuide bien:")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ForEach(Array(items.enumerated()), id: \.element.text) { index, item in
                HStack(spacing: 12) {
                    IconChip(symbol: item.symbol, color: .accentColor, size: 34)
                        .symbolEffect(.bounce, options: .nonRepeating, value: appeared)
                    Text(item.text).font(.headline)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 10)
                .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.8)
                    .delay(0.25 + 0.3 * Double(index)), value: appeared)
            }
        }
        .padding(16)
        .background(Color.accentColor.opacity(0.07), in: .rect(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.accentColor.opacity(0.15)))
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .onAppear { appeared = true }
    }
}

/// Motivos del cuidado en una fila compacta mientras se responden las preguntas.
private struct CarefulReasonChips: View {
    let reasons: [String]

    var body: some View {
        let items = reasons.compactMap { CarefulReasonsList.texts[$0] }
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { chips(items) }
            VStack(alignment: .leading, spacing: 8) { chips(items) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private func chips(_ items: [(text: String, symbol: String)]) -> some View {
        ForEach(items, id: \.text) { item in
            MetaChip(symbol: item.symbol, text: item.text, color: .accentColor)
        }
    }
}

/// Hasta 3 preguntas para afinar un Kit delicado: elegir una, varias o escribir.
private struct KitQuestionsCard: View {
    let questions: [KitQuestion]
    let onSubmit: ([KitAnswer]) -> Void
    let onSkip: () -> Void
    @State private var single: [String: String] = [:]
    @State private var multi: [String: Set<String>] = [:]
    @State private var text: [String: String] = [:]
    @FocusState private var focused: String?
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private func value(for question: KitQuestion) -> String {
        switch question.kind {
        case .single: single[question.id] ?? ""
        case .multi: question.options.filter { multi[question.id, default: []].contains($0) }.joined(separator: ", ")
        case .text: (text[question.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private var answers: [KitAnswer] {
        questions.compactMap { question in
            let answer = value(for: question)
            return answer.isEmpty ? nil : KitAnswer(id: question.id, question: question.text, value: answer)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Con tus respuestas el plan se adapta mejor a ti. Puedes saltarlas.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ForEach(Array(questions.enumerated()), id: \.element.id) { index, question in
                VStack(alignment: .leading, spacing: 10) {
                    Text(question.text).font(.headline)
                    switch question.kind {
                    case .single, .multi:
                        VStack(spacing: 8) {
                            ForEach(question.options, id: \.self) { option in
                                optionButton(option, in: question)
                            }
                        }
                    case .text:
                        TextField("Escribe tu respuesta", text: Binding(
                            get: { text[question.id] ?? "" },
                            set: { text[question.id] = $0 }
                        ), axis: .vertical)
                        .lineLimit(1...4)
                        .focused($focused, equals: question.id)
                        .padding(12)
                        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
                        .accessibilityIdentifier("kitQuestion.\(question.id)")
                    }
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)
                .animation(reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.85)
                    .delay(0.25 + 0.15 * Double(index)), value: appeared)
            }
            VStack(spacing: 10) {
                Button {
                    focused = nil
                    onSubmit(answers)
                } label: {
                    Text("Crear mi plan").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(answers.isEmpty)
                .accessibilityIdentifier("kitQuestions.submit")
                Button("Saltar y crear el plan", action: onSkip)
                    .font(.subheadline)
                    .accessibilityIdentifier("kitQuestions.skip")
            }
        }
        .padding(16)
        .background(Color.accentColor.opacity(0.07), in: .rect(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.accentColor.opacity(0.15)))
        .onAppear { appeared = true }
    }

    private func optionButton(_ option: String, in question: KitQuestion) -> some View {
        let selected = question.kind == .single
            ? single[question.id] == option
            : multi[question.id, default: []].contains(option)
        return Button {
            withAnimation(.snappy) {
                if question.kind == .single {
                    single[question.id] = option
                } else if selected {
                    multi[question.id, default: []].remove(option)
                } else {
                    multi[question.id, default: []].insert(option)
                }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: question.kind == .single
                      ? (selected ? "largecircle.fill.circle" : "circle")
                      : (selected ? "checkmark.square.fill" : "square"))
                    .foregroundStyle(selected ? Color.accentColor : .secondary)
                    .contentTransition(.symbolEffect(.replace))
                Text(option)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(selected ? Color.accentColor.opacity(0.12) : Color(.secondarySystemGroupedBackground),
                        in: .rect(cornerRadius: 14))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: selected)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Halo que respira alrededor de la esfera mientras se prepara un plan con cuidado.
private struct CarefulHalo: View {
    let diameter: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing = false

    var body: some View {
        ZStack {
            ForEach(0..<2, id: \.self) { ring in
                Circle()
                    .stroke(Color.accentColor.opacity(0.35), lineWidth: 1.5)
                    .frame(width: diameter * 1.5, height: diameter * 1.5)
                    .scaleEffect(breathing ? 1.9 : 1)
                    .opacity(breathing ? 0 : 0.8)
                    .animation(reduceMotion ? nil : .easeOut(duration: 2.4).repeatForever(autoreverses: false)
                        .delay(1.2 * Double(ring)), value: breathing)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { breathing = !reduceMotion }
    }
}

private struct SmoothProgressBar: View {
    var value: Double
    @State private var shimmer = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width * max(0.02, min(1, value))
            ZStack(alignment: .leading) {
                Capsule().fill(Color.accentColor.opacity(0.14))
                Capsule()
                    .fill(LinearGradient(colors: [Color(red: 0.05, green: 0.50, blue: 1.0),
                                                  Color(red: 0.45, green: 0.80, blue: 1.0)],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: width)
                    .overlay(alignment: .leading) {
                        if !reduceMotion {
                            LinearGradient(colors: [.clear, .white.opacity(0.45), .clear],
                                           startPoint: .leading, endPoint: .trailing)
                                .frame(width: 60)
                                .offset(x: shimmer ? width : -60)
                                .clipShape(Capsule())
                        }
                    }
                    .clipShape(Capsule())
                    .shadow(color: Color.accentColor.opacity(0.35), radius: 6, y: 2)
            }
        }
        .frame(height: 10)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) { shimmer = true }
        }
    }
}
