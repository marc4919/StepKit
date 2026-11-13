//
//  StepDetailComponents.swift
//  StepKit
//

import SwiftUI
import TipKit
import SwiftData
import NaturalLanguage
import os

/// Texto e icono en la barra inferior del iPhone. En el Duo, un `Label`, que la barra dibuja solo con
/// el icono: su barra pasa de abajo a la franja lateral al plegar, y con una vista propia los botones
/// desaparecían al desplegar hasta volver a entrar en el paso. Se decide por dispositivo, nunca por
/// postura, para que el botón sea siempre el mismo.
struct StepActionLabel: View {
    let title: String
    let symbol: String
    /// En la barra, en modo oscuro, el sistema pone negro el texto del botón principal: 3,9:1 sobre el azul.
    var tint: Color = .primary
    var showsText = true

    var body: some View {
        if !showsText {
            Label(title, systemImage: symbol)
                .foregroundStyle(tint)
        } else {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                Text(title).lineLimit(1).fixedSize()
            }
            .foregroundStyle(tint)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(title)
        }
    }
}

/// Texto largo en párrafos cortos: respeta los saltos que trae y, si no hay, agrupa de dos en dos frases.
struct ParagraphText: View {
    let text: String

    static func paragraphs(of text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let explicit = trimmed.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        if explicit.count > 1 || trimmed.count < 220 { return explicit }
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = trimmed
        var sentences: [String] = []
        tokenizer.enumerateTokens(in: trimmed.startIndex..<trimmed.endIndex) { range, _ in
            sentences.append(trimmed[range].trimmingCharacters(in: .whitespaces))
            return true
        }
        guard sentences.count > 2 else { return [trimmed] }
        return stride(from: 0, to: sentences.count, by: 2).map {
            sentences[$0..<min($0 + 2, sentences.count)].joined(separator: " ")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(Self.paragraphs(of: text).enumerated()), id: \.offset) { _, paragraph in
                Text(paragraph)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Sesiones de un paso que se repite: cada círculo es un día (o una semana) y se marca al hacerlo.
struct HabitSessionsCard: View {
    let step: StepEntity
    let doneDays: Set<DateComponents>
    let onToggle: (Date) -> Void
    let onCompleteStep: () -> Void

    private var dates: [Date] { step.sessionDates }
    private var doneCount: Int { dates.filter { doneDays.contains(DateComponents.day(of: $0)) }.count }

    var body: some View {
        PlainCard {
            HStack(alignment: .firstTextBaseline) {
                Text("Tus sesiones").font(.headline)
                Spacer()
                Text("\(doneCount) de \(dates.count)")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(doneCount == dates.count ? MetaTint.done : .secondary)
                    .contentTransition(.numericText())
            }
            ProgressView(value: Double(doneCount), total: Double(max(dates.count, 1)))
                .tint(MetaTint.repeatTint)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 10) {
                ForEach(dates, id: \.self) { date in
                    sessionButton(date)
                }
            }
            if doneCount == dates.count, !step.isCompleted {
                VStack(spacing: 8) {
                    Label("Sesiones cumplidas", systemImage: "checkmark.seal.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MetaTint.done)
                    Button(action: onCompleteStep) {
                        Text("Completar paso").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(MetaTint.done)
                }
                .frame(maxWidth: .infinity)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .sensoryFeedback(.success, trigger: doneCount == dates.count)
    }

    private func sessionButton(_ date: Date) -> some View {
        let done = doneDays.contains(DateComponents.day(of: date))
        let isToday = Calendar.current.isDateInToday(date)
        let weekly = step.repetition?.every == .week
        return Button { onToggle(date) } label: {
            VStack(spacing: 3) {
                Text(weekly ? String(localized: "S\((dates.firstIndex(of: date) ?? 0) + 1)")
                            : date.formatted(.dateTime.weekday(.narrow)))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isToday ? Color.accentColor : .secondary)
                ZStack {
                    Circle()
                        .fill(done ? MetaTint.repeatTint : Color.clear)
                    Circle()
                        .strokeBorder(done ? MetaTint.repeatTint : (isToday ? Color.accentColor : Color.secondary.opacity(0.35)),
                                      lineWidth: isToday && !done ? 2 : 1.5)
                    if done {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Text(date.formatted(.dateTime.day()))
                            .font(.caption.weight(.medium).monospacedDigit())
                            .foregroundStyle(.primary)
                    }
                }
                .frame(width: 34, height: 34)
            }
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: done)
        .accessibilityLabel("\(step.repetition?.sessionName(dates.firstIndex(of: date) ?? 0) ?? ""), \(date.formatted(.dateTime.weekday(.wide).day().month(.wide)))")
        .accessibilityValue(done ? String(localized: "Hecha") : String(localized: "Pendiente"))
        .accessibilityAddTraits(done ? .isSelected : [])
    }
}

/// Para alternar entre estilos de botón del sistema sin duplicar la vista.
struct AnyPrimitiveButtonStyle: PrimitiveButtonStyle {
    private let make: (Configuration) -> AnyView

    init<S: PrimitiveButtonStyle>(_ style: S) {
        make = { AnyView(style.makeBody(configuration: $0)) }
    }

    func makeBody(configuration: Configuration) -> some View { make(configuration) }
}

// MARK: - Aviso al completar

struct Celebration: Equatable {
    let id = UUID()
    let nextStepID: UUID?
    let nextTitle: String?
    /// Era el último pendiente: el aviso lleva a la pantalla de Kit completado.
    var kitDone = false
}

/// Confirmación breve y visible al completar: el check se anima y dice qué viene después.
struct CompletionBanner: View {
    let celebration: Celebration
    let onOpenNext: () -> Void
    @State private var appeared = false

    var body: some View {
        if celebration.nextStepID != nil || celebration.kitDone {
            Button(action: onOpenNext) { content(showsChevron: true) }
                .buttonStyle(.plain)
                .accessibilityHint(celebration.kitDone ? String(localized: "Abre el resumen del Kit completado") : String(localized: "Abre el siguiente paso"))
                .accessibilityIdentifier("step.openNext")
        } else {
            content(showsChevron: false)
        }
    }

    private func content(showsChevron: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title)
                .foregroundStyle(.green)
                .symbolEffect(.bounce, value: appeared)
            VStack(alignment: .leading, spacing: 2) {
                Text(celebration.kitDone ? String(localized: "¡Kit completado!") : String(localized: "¡Paso completado!")).font(.headline)
                Text(celebration.kitDone ? String(localized: "Era el último paso. Revisa cómo te ha ido.")
                     : celebration.nextTitle.map { String(localized: "Siguiente: \($0)") } ?? String(localized: "Era el último paso del Kit."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .contentShape(.rect(cornerRadius: 22))
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 22))
        .padding(.horizontal)
        .onAppear { appeared = true }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }
}
