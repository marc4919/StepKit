//
//  StepDetailView+Sections.swift
//  StepKit
//

import SwiftUI
import TipKit
import SwiftData

extension StepDetailView {
    var stepHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(text: String(localized: "Paso \(stepNumber) · \(state.label)"),
                    color: state == .pending ? .accentColor : state.tint)
            Text(stepEntity.stepTitle)
                .font(.largeTitle.bold())
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
    }

    @ViewBuilder var stepWhatToDo: some View {
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

    @ViewBuilder var stepProgress: some View {
        if let reason = stepEntity.blockedReason {
            blockedCards(reason: reason)
        } else if !progressNotes.isEmpty {
            progressHistoryCard
        }
    }

    @ViewBuilder var stepDetails: some View {
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

    var stepReminder: some View {
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
}
