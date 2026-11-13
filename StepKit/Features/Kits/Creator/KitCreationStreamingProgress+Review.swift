//
//  KitCreationStreamingProgress+Review.swift
//  StepKit
//

import SwiftUI

extension KitCreationStreamingProgress {
    // MARK: - Revisar el plan

    var reviewView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if reviewWide {
                    // Pantalla ancha (iPhone Duo abierto, iPad): resumen a la izquierda, «A tener en cuenta» a la derecha.
                    reviewHeader
                    reviewNote
                    // Izquierda: meta y primer paso. Derecha: «A tener en cuenta», la nota y los botones,
                    // siempre a la vista sin tapar la lista de pasos.
                    HStack(alignment: .top, spacing: 24) {
                        VStack(alignment: .leading, spacing: 18) {
                            reviewKPI
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        VStack(alignment: .leading, spacing: 18) {
                            reviewRisks
                            reviewActions
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    // Los pasos, debajo y a todo lo ancho.
                    reviewStepsList
                } else {
                    reviewHeader
                    reviewNote
                    reviewKPI
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
            .tint(.primaryAction)
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
                    // La fecha final, como en el chip del Kit: los días los cuenta el resumen de abajo.
                    if let days = streamingState.horizonDays, days >= 0,
                       let due = Calendar.current.date(byAdding: .day, value: days, to: Calendar.current.startOfDay(for: .now)) {
                        MetaChip(symbol: Symbols.wantedDate, text: PlanGrouping.shortDate(due), color: MetaTint.date)
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
        if KitCreationHints.visible {
            Text("Revisa el plan antes de empezar. Podrás editar los pasos después.")
                .foregroundStyle(.secondary)
                .modifier(Reveal(shown: contentRevealed, order: 2))
        }
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
                        // Resumen: qué queda hecho, y el tiempo y el esfuerzo en una línea. La descripción
                        // larga se lee en el paso: cortada a tres líneas aquí no aportaba y alargaba la lista.
                        VStack(alignment: .leading, spacing: 6) {
                            if !step.description.short.isEmpty {
                                Text("Al terminar").font(.caption.weight(.semibold))
                                Text(step.description.short).font(.subheadline)
                            }
                            HStack(spacing: 10) {
                                Label(String(localized: "\(step.estimateMinutes) min"), systemImage: Symbols.time)
                                    .foregroundStyle(MetaTint.time)
                                Label(String(localized: "Esfuerzo \(StepDetailHelpers.effortLevelText(for: step.effortLevel).lowercased())"),
                                      systemImage: Symbols.effort)
                                    .foregroundStyle(MetaTint.effort)
                            }
                            .font(.caption.weight(.medium))
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
}
