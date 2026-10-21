//
//  KitCreationStreamingProgress.swift
//  StepKit
//
//  Crear Kit v4.4: «Dando forma a tu proyecto» mientras llegan los pasos y, al
//  terminar, «Tu plan» para revisarlo antes de aceptarlo.
//

import SwiftUI

struct KitCreationStreamingProgress: View {
    @Binding var streamingState: KitStreamingState
    let onSave: () -> Void
    let onDiscard: () -> Void
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Progreso de la preparación: arranque, resultado recibido y pasos llegando.
    private var targetProgress: Double {
        if finalFill { return 1 }
        if streamingState.isComplete { return 0.95 }
        guard streamingState.kitTitle != nil else { return 0.12 }
        let received = Double(streamingState.steps.count)
        if let total = streamingState.totalSteps, total > 0 {
            return 0.25 + 0.7 * received / Double(total)
        }
        // Sin total (el servidor ya no lo anuncia): cada paso acerca la barra, sin llegar al final.
        return 0.25 + 0.65 * (1 - pow(0.8, received))
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
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                // La esfera se forma mientras avanza la barra y, al terminar, despega.
                OrbitMark(height: 190, buildProgress: shownProgress, liftOff: liftOff, hidesSphere: sphereInFlight)
                    .overlay {
                        // Hueco de la esfera (190 × 0,31): de aquí sale hacia «Tu plan».
                        Color.clear
                            .frame(width: 59, height: 59)
                            .matchedGeometryEffect(id: "sphere", in: sphereSpace, isSource: !showReview)
                    }
                    .padding(.horizontal, 20)
                ZStack {
                    Text(headline)
                        .font(.title.bold())
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
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
                if showCareful {
                    CarefulReasonsList(reasons: streamingState.carefulReasons)
                        .padding(.horizontal, 30)
                        .transition(Self.swap)
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        phase(done: streamingState.kitTitle != nil, active: streamingState.kitTitle == nil,
                              title: "Resultado y supuestos",
                              detail: streamingState.isRestarting ? "Ajustando"
                                : streamingState.kitTitle == nil ? "Preparando" : "Recibido")
                        phase(done: stepsChecked,
                              active: streamingState.kitTitle != nil && !stepsChecked,
                              title: "Pasos del plan", detail: stepsDetail)
                        phase(done: reviewChecked, active: stepsChecked && !reviewChecked,
                              title: "Plan listo para revisar",
                              detail: reviewChecked ? "Listo" : "Lo revisarás tú antes de empezar")
                    }
                    .opacity(streamingState.isRestarting ? 0.45 : 1)
                    .padding(.horizontal, 30)
                    .transition(Self.swap)
                }
                SmoothProgressBar(value: shownProgress)
                    .padding(.horizontal, 30)
                    .accessibilityElement()
                    .accessibilityLabel("Progreso del plan")
                    .accessibilityValue(Text(shownProgress, format: .percent.precision(.fractionLength(0))))
                Text("Puedes cancelar: tu idea se conserva en el formulario.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .padding(.vertical)
        }
        .background { EntryBackground() }
        // Hápticos sutiles: un toque ligero por cada check y éxito al despegar.
        .sensoryFeedback(.impact(weight: .light), trigger: streamingState.kitTitle != nil)
        .sensoryFeedback(.impact(weight: .light), trigger: stepsChecked)
        .sensoryFeedback(.impact(weight: .light), trigger: reviewChecked)
        .sensoryFeedback(.success, trigger: liftOff)
        .onAppear {
            advance(to: targetProgress)
            if streamingState.isCareful && streamingState.kitTitle == nil { presentCareful() }
        }
        .onChange(of: targetProgress) { _, value in advance(to: value) }
        .onChange(of: streamingState.isCareful) { _, careful in
            if careful && streamingState.kitTitle == nil { presentCareful() }
        }
        .onChange(of: streamingState.kitTitle != nil) { _, hasTitle in
            if hasTitle { dismissCareful() }
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
                let ceiling = min(0.9, targetProgress + 0.15)
                if shownProgress < ceiling {
                    let step = max(0.002, (ceiling - shownProgress) * 0.05)
                    advance(to: min(ceiling, shownProgress + step), duration: 0.45)
                }
            }
        }
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

    /// Relevo de textos sin solaparse: lo anterior se va antes de que llegue lo nuevo.
    private static let swap: AnyTransition = .asymmetric(
        insertion: .opacity.animation(.easeOut(duration: 0.35).delay(0.25)),
        removal: .opacity.animation(.easeIn(duration: 0.2))
    )

    private var headline: String {
        if streamingState.isRestarting { return "Ajustando tu plan…" }
        if showCareful { return "Preparando tu plan con más cuidado" }
        return "Dando forma a tu proyecto"
    }

    private func presentCareful() {
        carefulShownAt = .now
        if reduceMotion {
            showCareful = true
        } else {
            withAnimation(.easeInOut(duration: 0.4)) { showCareful = true }
        }
    }

    /// Se desvanece al llegar el título; si apenas se ha visto, aguanta hasta ~1 s para no parpadear.
    /// No retrasa nada: el plan sigue llegando por detrás.
    private func dismissCareful() {
        guard showCareful else { return }
        let elapsed = carefulShownAt.map { Date.now.timeIntervalSince($0) } ?? 1
        Task {
            if elapsed < 1 { try? await Task.sleep(for: .seconds(1 - elapsed)) }
            if reduceMotion {
                showCareful = false
            } else {
                withAnimation(.easeInOut(duration: 0.5)) { showCareful = false }
            }
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

    private var stepsDetail: String {
        if let total = streamingState.totalSteps {
            return "Recibidos \(streamingState.steps.count) de \(total)"
        }
        if !streamingState.steps.isEmpty {
            return streamingState.steps.count == 1 ? "Recibido 1" : "Recibidos \(streamingState.steps.count)"
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
                if let kpi = streamingState.kpi, !kpi.isEmpty {
                    PlainCard {
                        Eyebrow(text: "Sabrás que está listo cuando", color: .secondary)
                        Text(kpi)
                    }
                    .modifier(Reveal(shown: contentRevealed, order: 1))
                }
                Text("Revisa el plan antes de empezar. Podrás editar los pasos después.")
                    .foregroundStyle(.secondary)
                    .modifier(Reveal(shown: contentRevealed, order: 2))
                if let first = streamingState.steps.first {
                    TintCard {
                        HStack(alignment: .top, spacing: 12) {
                            NextMark()
                            VStack(alignment: .leading, spacing: 3) {
                                Eyebrow(text: "Tu primer paso")
                                Text(first.stepTitle).font(.title3.bold())
                                Label("\(first.estimateMinutes) min orientativos", systemImage: Symbols.time)
                                    .font(.subheadline)
                                    .foregroundStyle(MetaTint.time)
                            }
                        }
                    }
                    .modifier(Reveal(shown: contentRevealed, order: 3))
                }
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
                                Label("\(step.estimateMinutes) min", systemImage: Symbols.time)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(MetaTint.time)
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
                if !streamingState.risks.isEmpty {
                    PlainCard {
                        Eyebrow(text: "A tener en cuenta", color: .secondary)
                        ForEach(streamingState.risks, id: \.self) { risk in
                            Label(risk, systemImage: Symbols.risk)
                                .foregroundStyle(.secondary)
                                .symbolRenderingMode(.multicolor)
                        }
                    }
                    .modifier(Reveal(shown: contentRevealed, order: 5))
                }
            }
            .padding()
        }
        .background(alignment: .top) { BrandGlow() }
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) {
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
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.bar)
            .modifier(Reveal(shown: contentRevealed, order: 3))
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

    private static let texts: [String: (text: String, symbol: String)] = [
        "health": ("Afecta a tu salud", "heart"),
        "mental_health": ("Cuida tu bienestar emocional", "leaf"),
        "substances": ("Implica dejar o reducir una sustancia", "hand.raised"),
        "disability": ("Adaptado a tu situación", "figure.roll"),
        "financial_risk": ("Hay dinero en juego", "eurosign.circle"),
        "legal": ("Buscamos una alternativa legal", "checkmark.shield"),
        "tight_deadline": ("El plazo es muy corto", "clock")
    ]

    private var items: [(text: String, symbol: String)] {
        reasons.compactMap { Self.texts[$0] }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Me tomo unos segundos más para que el plan te cuide bien.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ForEach(items, id: \.text) { item in
                HStack(spacing: 12) {
                    IconChip(symbol: item.symbol, color: .accentColor, size: 34)
                    Text(item.text).font(.headline)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
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
