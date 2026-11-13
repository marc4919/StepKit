//
//  PlanStepRow.swift
//  StepKit
//

import SwiftUI
import TipKit
import SwiftData

// MARK: - Fila del plan

struct PlanStepRow: View {
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
            .accessibilityHint("Abre el paso")
            .accessibilityIdentifier("step.row")
        }
        .animation(.easeInOut(duration: 0.6), value: highlight)
    }
}
