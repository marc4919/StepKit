//
//  AssistantHomeView.swift
//  StepKit
//
//  Asistente v4.4: intenciones para empezar, respuestas como contenido con barra
//  de acento e identificación sobria, y composer con Liquid Glass sobre el contenido.
//

import SwiftUI

/// Intención de ayuda centrada en el siguiente paso del Kit elegido.
struct AssistantIntent: Identifiable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let color: Color

    static let all: [AssistantIntent] = [
        AssistantIntent(id: "less-time", title: "Tengo menos tiempo",
                        detail: "Buscar un tramo más pequeño para ahora", symbol: Symbols.time, color: .blue),
        AssistantIntent(id: "how-to-start", title: "No sé cómo empezar",
                        detail: "Aclarar la primera acción", symbol: "arrow.turn.down.right", color: .accentColor),
        AssistantIntent(id: "missing", title: "Me falta algo",
                        detail: "Revisar un bloqueo sin perder lo hecho", symbol: Symbols.blocked, color: .red),
        AssistantIntent(id: "not-fitting", title: "Este paso ya no encaja",
                        detail: "Pensar un cambio que decidirás tú", symbol: "pencil", color: .purple),
    ]

    /// Mensaje que se envía al modelo; menciona el Kit y el paso para no depender de la memoria.
    func prompt(kit: GoalEntity?) -> String {
        let kitName = kit?.title ?? "mi Kit"
        let step = kit?.nextStep
        let stepText = step.map { "«\($0.stepTitle)» (\($0.estimateMinutes) min)" } ?? "el siguiente paso"
        switch id {
        case "less-time":
            return "Hoy tengo poco tiempo. En \(kitName), ¿qué tramo pequeño de \(stepText) puedo hacer ahora?"
        case "how-to-start":
            return "No sé cómo empezar \(stepText) en \(kitName). ¿Cuál sería la primera acción concreta?"
        case "missing":
            let reason = step?.blockedReason.map { " Me frena: \($0)." } ?? ""
            return "Me falta algo para avanzar en \(stepText) de \(kitName).\(reason) ¿Cómo puedo seguir sin perder lo hecho?"
        default:
            return "Creo que \(stepText) ya no encaja en \(kitName). ¿Qué cambio me propondrías? Lo decidiré yo."
        }
    }
}

struct AssistantHomeView: View {
    let messages: [ChatMessage]
    @Binding var draft: String
    let isTyping: Bool
    let isResponding: Bool
    var isInputFocused: FocusState<Bool>.Binding
    let onSend: () -> Void
    let onIntent: (AssistantIntent) -> Void
    var onRetry: (() -> Void)?

    private var lastIntentRetry: (() -> Void)? { isResponding ? nil : onRetry }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if messages.isEmpty {
                    start
                } else {
                    conversation
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: messages.last?.text) { _, _ in
                withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
            }
            .onChange(of: isTyping) { _, _ in
                withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
            }
        }
        .background(alignment: .top) { BrandGlow() }
        .background(Color(.systemGroupedBackground))
        .safeAreaBar(edge: .bottom) { composer }
    }

    private var start: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("¿Por dónde seguimos?")
                .font(.largeTitle.bold())
                .accessibilityAddTraits(.isHeader)
            Text("Elige qué necesitas y revisamos tu siguiente paso.")
                .foregroundStyle(.secondary)
                .padding(.bottom, 6)
            ForEach(AssistantIntent.all) { intent in
                Button { onIntent(intent) } label: { IntentCard(intent: intent) }
                    .buttonStyle(.plain)
                    .disabled(isResponding)
                    .accessibilityIdentifier("assistant.intent.\(intent.id)")
            }
            Text("Las respuestas se generan en tu dispositivo. Revisa siempre lo que propongan antes de cambiar tu plan.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .padding()
    }

    private var conversation: some View {
        LazyVStack(alignment: .leading, spacing: 18) {
            ForEach(messages) { message in
                switch message.sender {
                case .user:
                    HStack {
                        Spacer(minLength: 60)
                        Text(message.text)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 11)
                            .background(Color.accentColor.opacity(0.14), in: .rect(cornerRadius: 20))
                    }
                    .accessibilityLabel("Tú: \(message.text)")
                case .assistant where message.isError:
                    AssistantUnavailableCard(onRetry: lastIntentRetry)
                case .assistant:
                    AssistantAnswer(message: message)
                }
            }
            if isTyping {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Pensando…").foregroundStyle(.secondary)
                }
                .font(.subheadline)
            }
            Color.clear.frame(height: 1).id("bottom")
        }
        .padding()
    }

    private var composer: some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(AssistantIntent.all) { intent in
                    Button(intent.title, systemImage: intent.symbol) { onIntent(intent) }
                }
            } label: {
                Label("Sugerencias", systemImage: "list.bullet")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.glass)
            .controlSize(.large)
            .disabled(isResponding)

            TextField("¿Qué necesitas ahora?", text: $draft, axis: .vertical)
                .lineLimit(1...5)
                .focused(isInputFocused)
                .submitLabel(.send)
                .onSubmit(onSend)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .glassEffect(.regular.interactive(), in: .capsule)
                .accessibilityIdentifier("assistant.input")

            Button("Enviar", systemImage: "arrow.up", action: onSend)
                .labelStyle(.iconOnly)
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .disabled(isResponding || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("assistant.send")
        }
        .padding(.horizontal)
        .padding(.bottom, 6)
    }
}

private struct IntentCard: View {
    let intent: AssistantIntent

    var body: some View {
        HStack(spacing: 14) {
            IconChip(symbol: intent.symbol, color: intent.color, size: 42)
            VStack(alignment: .leading, spacing: 2) {
                Text(intent.title).font(.headline).foregroundStyle(.primary)
                Text(intent.detail).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18))
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

/// Respuesta como contenido, con barra de acento e identificación sobria del origen.
private struct AssistantAnswer: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Rectangle().fill(Color.accentColor).frame(width: 3).clipShape(.capsule)
            VStack(alignment: .leading, spacing: 6) {
                Text(LocalizedStringKey(message.text))
                    .font(.body)
                    .textSelection(.enabled)
                Text("Generado en tu dispositivo · \(message.timestamp.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// La ayuda no está disponible: el plan y los avances siguen intactos.
private struct AssistantUnavailableCard: View {
    let onRetry: (() -> Void)?

    var body: some View {
        PlainCard {
            HStack(alignment: .top, spacing: 12) {
                IconChip(symbol: "bubble.left.and.exclamationmark.bubble.right", color: .accentColor)
                VStack(alignment: .leading, spacing: 3) {
                    Text("La ayuda no está disponible ahora").font(.headline)
                    Text("Puedes seguir con tu proyecto. Tu plan y tus avances siguen aquí.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            if let onRetry {
                Button("Reintentar", systemImage: "arrow.clockwise", action: onRetry)
                    .buttonStyle(.bordered)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
