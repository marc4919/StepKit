//
//  KitCreationStreamingParts.swift
//  StepKit
//

import SwiftUI

/// Barra de progreso suave con degradado de la marca y brillo que recorre la parte completada.
/// Aparición en cascada de «Tu plan» tras dibujarse el anillo.
/// Entrada escalonada: cada elemento aparece un poco después del anterior.
struct Reveal: ViewModifier {
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
struct CarefulReasonsList: View {
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
struct CarefulReasonChips: View {
    let reasons: [String]

    var body: some View {
        let items = reasons.compactMap { CarefulReasonsList.texts[$0] }
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { chips(items) }
            VStack(alignment: .leading, spacing: 8) { chips(items) }
            // Con letra muy grande un motivo no cabe en una línea: parte líneas.
            VStack(alignment: .leading, spacing: 8) { chips(items, wraps: true) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private func chips(_ items: [(text: String, symbol: String)], wraps: Bool = false) -> some View {
        ForEach(items, id: \.text) { item in
            MetaChip(symbol: item.symbol, text: item.text, color: .accentColor, wraps: wraps)
        }
    }
}

/// Hasta 3 preguntas para afinar un Kit delicado: elegir una, varias o escribir.
struct KitQuestionsCard: View {
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
                .tint(.primaryAction)
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
struct CarefulHalo: View {
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

struct SmoothProgressBar: View {
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
