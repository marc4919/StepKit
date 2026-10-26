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
    @State private var liftOff = false
    @State private var stepsChecked = false
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
                } else if showReview {
                    reviewView
                        .transition(.opacity)
                } else {
                    preparingView
                        .transition(.opacity)
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
                          title: "Tu objetivo",
                          detail: streamingState.isRestarting ? "Ajustando"
                            : streamingState.kitTitle == nil ? "Preparando" : "Listo")
                    phase(done: stepsChecked,
                          active: streamingState.kitTitle != nil && !stepsChecked,
                          title: "Pasos del plan", detail: stepsDetail)
                    phase(done: reviewChecked, active: stepsChecked && !reviewChecked,
                          title: "Plan listo para revisar",
                          detail: reviewChecked ? "Listo" : "Lo revisarás tú antes de empezar")
                }
                .opacity(streamingState.isRestarting ? 0.45 : 1)
                .padding(.horizontal, 30)
                SmoothProgressBar(value: shownProgress)
                    .padding(.horizontal, 30)
                    .accessibilityElement()
                    .accessibilityLabel("Progreso del plan")
                    .accessibilityValue(Text(shownProgress, format: .percent.precision(.fractionLength(0))))
    }

    /// Relevo de textos sin solaparse: lo anterior se va antes de que llegue lo nuevo.
    private static let swap: AnyTransition = .asymmetric(
        insertion: .opacity.animation(.easeOut(duration: 0.35).delay(0.25)),
        removal: .opacity.animation(.easeIn(duration: 0.2))
    )

    private var headline: String {
        if streamingState.isRestarting { return "Ajustando tu plan…" }
        if questionsVisible { return "Antes de prepararlo, cuéntame un poco más" }
        if showCareful { return "Preparando tu plan con más cuidado" }
        return "Dando forma a tu Kit"
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
    private static func stepDay(_ text: String) -> String? {
        let parser = DateFormatter()
        parser.calendar = Calendar(identifier: .gregorian)
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"
        return parser.date(from: text)?.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    private var stepsDetail: String {
        if let total = streamingState.totalSteps {
            return "\(streamingState.steps.count) de \(total) listos"
        }
        if !streamingState.steps.isEmpty {
            return streamingState.steps.count == 1 ? "1 paso listo" : "\(streamingState.steps.count) pasos listos"
        }
        return streamingState.kitTitle == nil ? "Pendiente" : "Preparando"
    }

    private func phase(done: Bool, active: Bool, title: String, detail: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: done ? "checkmark.circle.fill" : active ? "circle.dotted" : "circle")
                .font(.title2)
                .foregroundStyle(done ? Color.green : active ? Color.accentColor : Color.secondary)
                .symbolEffect(.pulse, isActive: active)
                .contentTransition(.symbolEffect(.replace))
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
                            reviewFirstStep
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
                    reviewFirstStep
                    reviewStepsList
                    reviewRisks
                }
            }
            .padding()
        }
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
                Text(streamingState.kitTitle ?? "Tu plan")
                    .font(.title2.bold())
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    MetaChip(symbol: "list.bullet", text: "\(streamingState.steps.count) pasos", color: .accentColor)
                    if let days = streamingState.horizonDays {
                        MetaChip(symbol: Symbols.wantedDate, text: "\(days) días", color: MetaTint.date)
                    }
                }
            }
            .modifier(Reveal(shown: contentRevealed, order: 0))
        }
    }

    @ViewBuilder private var reviewKPI: some View {
        if let kpi = streamingState.kpi, !kpi.isEmpty {
            PlainCard {
                Eyebrow(text: "Sabrás que está listo cuando", color: .secondary)
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

    @ViewBuilder private var reviewFirstStep: some View {
        if let first = streamingState.steps.first {
            TintCard {
                HStack(alignment: .top, spacing: 12) {
                    NextMark()
                    VStack(alignment: .leading, spacing: 3) {
                        Eyebrow(text: "Tu primer paso")
                        Text(first.stepTitle).font(.title3.bold())
                        HStack(spacing: 10) {
                            if let day = Self.stepDay(first.suggestedDeadline) {
                                Label(day, systemImage: Symbols.calendar)
                                    .foregroundStyle(MetaTint.date)
                            }
                            Label("\(first.estimateMinutes) min orientativos", systemImage: Symbols.time)
                                .foregroundStyle(MetaTint.time)
                        }
                        .font(.subheadline)
                    }
                }
            }
            .modifier(Reveal(shown: contentRevealed, order: 3))
        }
    }

    @ViewBuilder private var reviewStepsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(streamingState.steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.subheadline.bold().monospacedDigit())
                        .foregroundStyle(.tint)
                        .frame(width: 28, height: 28)
                        .background(Color.accentColor.opacity(0.12), in: .circle)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(step.stepTitle)
                        HStack(spacing: 10) {
                            if let day = Self.stepDay(step.suggestedDeadline) {
                                Label(day, systemImage: Symbols.calendar)
                                    .foregroundStyle(MetaTint.date)
                            }
                            Label("\(step.estimateMinutes) min", systemImage: Symbols.time)
                                .foregroundStyle(MetaTint.time)
                            if let repetition = step.repetition?.repetition {
                                Label(repetition.label, systemImage: "repeat")
                                    .foregroundStyle(MetaTint.repeatTint)
                            }
                        }
                        .font(.caption.weight(.medium))
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .accessibilityElement(children: .combine)
                if index < streamingState.steps.count - 1 {
                    Divider().padding(.leading, 52)
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18))
        .modifier(Reveal(shown: contentRevealed, order: 4))
    }

    @ViewBuilder private var reviewRisks: some View {
        if !streamingState.risks.isEmpty {
            PlainCard {
                Eyebrow(text: "A tener en cuenta", color: .secondary)
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
                Text(streamingState.error ?? "No se pudo preparar el plan.")
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
        "health": ("Afecta a tu salud", "heart"),
        "mental_health": ("Cuida tu bienestar emocional", "leaf"),
        "substances": ("Implica dejar o reducir una sustancia", "hand.raised"),
        "disability": ("Adaptado a tu situación", "figure.roll"),
        "financial_risk": ("Hay dinero en juego", "eurosign.circle"),
        "legal": ("Buscamos una alternativa legal", "checkmark.shield"),
        "tight_deadline": ("El plazo es muy corto", "clock"),
        "safety": ("Hay que hacerlo con seguridad", "exclamationmark.shield")
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
