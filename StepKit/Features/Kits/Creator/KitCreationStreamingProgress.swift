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
    @State var showReview = false
    @State private var reviewMounted = false
    @State private var liftOff = false
    @State private var stepsChecked = false
    /// Cuándo empezó la preparación: pasado un rato se explica qué se está haciendo.
    @State private var preparingSince = Date.now
    /// Pasos abiertos en la revisión para ver qué incluyen antes de crear el Kit.
    @State var expandedSteps: Set<Int> = []
    @State private var reviewChecked = false
    @State private var finalFill = false
    /// Pantalla de cuidado: visible desde plan_mode «careful» hasta que llega el título (mínimo ~1 s).
    @State private var showCareful = false
    /// Transición a «Tu plan»: la esfera viaja a su sitio, se dibuja el anillo y aparece el resto.
    @Namespace var sphereSpace
    @State private var sphereInFlight = false
    @State var sphereLanded = false
    @State var ringDrawn: CGFloat = 0
    @State var contentRevealed = false
    @State private var carefulShownAt: Date?
    /// Las preguntas entran después de que el aviso de cuidado se haya visto con calma.
    @State private var questionsVisible = false
    @State var reviewWide = false
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
    private static let swap: AnyTransition = .contentSwap

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
    static func stepDate(_ text: String) -> Date? {
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
                .tint(.primaryAction)
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
