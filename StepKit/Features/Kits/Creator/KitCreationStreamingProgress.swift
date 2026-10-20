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

    var body: some View {
        Group {
            if streamingState.hasError {
                errorView
            } else if streamingState.isComplete {
                reviewView
            } else {
                preparingView
            }
        }
        .animation(.easeInOut, value: streamingState.isComplete)
    }

    // MARK: - Preparando

    private var preparingView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                OrbitMark(height: 190).padding(.horizontal, 20)
                Text("Dando forma a tu proyecto")
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 16) {
                    phase(done: streamingState.kitTitle != nil, active: streamingState.kitTitle == nil,
                          title: "Resultado y supuestos",
                          detail: streamingState.kitTitle == nil ? "Preparando" : "Recibido")
                    phase(done: streamingState.isComplete,
                          active: streamingState.kitTitle != nil && !streamingState.isComplete,
                          title: "Pasos del plan", detail: stepsDetail)
                    phase(done: false, active: false, title: "Revisión", detail: "La harás tú antes de empezar")
                }
                .padding(.horizontal, 30)
                ProgressView(value: streamingState.progress)
                    .padding(.horizontal, 30)
                    .accessibilityLabel("Progreso del plan")
                Text("Puedes cancelar: tu idea se conserva en el formulario.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .padding(.vertical)
        }
        .background { EntryBackground() }
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
