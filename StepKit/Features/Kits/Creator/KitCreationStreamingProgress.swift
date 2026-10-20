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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Progreso de la preparación: arranque, resultado recibido y pasos llegando.
    private var targetProgress: Double {
        if reviewChecked { return 1 }
        if streamingState.isComplete { return 0.95 }
        guard streamingState.kitTitle != nil else { return 0.12 }
        guard let total = streamingState.totalSteps, total > 0 else { return 0.25 }
        return 0.25 + 0.75 * Double(streamingState.steps.count) / Double(total)
    }

    var body: some View {
        Group {
            if streamingState.hasError {
                errorView
            } else if showReview {
                reviewView
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                preparingView
            }
        }
        .animation(.easeInOut(duration: 0.5), value: showReview)
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
                OrbitMark(height: 190, buildProgress: shownProgress, liftOff: liftOff)
                    .padding(.horizontal, 20)
                Text("Dando forma a tu proyecto")
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 16) {
                    phase(done: streamingState.kitTitle != nil, active: streamingState.kitTitle == nil,
                          title: "Resultado y supuestos",
                          detail: streamingState.kitTitle == nil ? "Preparando" : "Recibido")
                    phase(done: stepsChecked,
                          active: streamingState.kitTitle != nil && !stepsChecked,
                          title: "Pasos del plan", detail: stepsDetail)
                    phase(done: reviewChecked, active: stepsChecked && !reviewChecked,
                          title: "Plan listo para revisar",
                          detail: reviewChecked ? "Listo" : "Lo revisarás tú antes de empezar")
                }
                .padding(.horizontal, 30)
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
        .onAppear { advance(to: targetProgress) }
        .onChange(of: targetProgress) { _, value in advance(to: value) }
        .task {
            // Avance lento mientras se espera el siguiente evento, sin pasar del siguiente tramo.
            while !Task.isCancelled && !reviewChecked {
                try? await Task.sleep(for: .milliseconds(450))
                let ceiling = min(0.97, targetProgress + 0.1)
                if shownProgress < ceiling {
                    advance(to: min(ceiling, shownProgress + 0.012), duration: 0.45)
                }
            }
        }
    }

    private func scheduleReview() {
        Task {
            guard !reduceMotion else {
                stepsChecked = true
                reviewChecked = true
                showReview = true
                return
            }
            // Primero se completan los checks, luego la barra, la esfera despega y aparece «Tu plan».
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { stepsChecked = true }
            try? await Task.sleep(for: .milliseconds(500))
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { reviewChecked = true }
            try? await Task.sleep(for: .milliseconds(900))
            withAnimation(.easeIn(duration: 0.75)) { liftOff = true }
            try? await Task.sleep(for: .milliseconds(800))
            showReview = true
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
                        ProgressRing(done: 0, total: max(streamingState.steps.count, 1), size: 70, showsLabel: false)
                        BrandSphere(size: 34, glow: false)
                    }
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
                }
                if let kpi = streamingState.kpi, !kpi.isEmpty {
                    PlainCard {
                        Eyebrow(text: "Sabrás que está listo cuando", color: .secondary)
                        Text(kpi)
                    }
                }
                Text("Revisa el plan antes de empezar. Podrás editar los pasos después.")
                    .foregroundStyle(.secondary)
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
                if !streamingState.risks.isEmpty {
                    PlainCard {
                        Eyebrow(text: "A tener en cuenta", color: .secondary)
                        ForEach(streamingState.risks, id: \.self) { risk in
                            Label(risk, systemImage: Symbols.risk)
                                .foregroundStyle(.secondary)
                                .symbolRenderingMode(.multicolor)
                        }
                    }
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
