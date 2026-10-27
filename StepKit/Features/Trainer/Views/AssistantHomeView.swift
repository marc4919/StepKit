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

    /// Intenciones sobre un paso.
    static let step: [AssistantIntent] = all + [
        AssistantIntent(id: "split", title: String(localized: "Ayúdame a dividir esta tarea"),
                        detail: String(localized: "Partirla en tramos más pequeños"), symbol: "square.split.2x1", color: .teal),
        AssistantIntent(id: "fifteen", title: String(localized: "¿Qué puedo avanzar en 15 minutos?"),
                        detail: String(localized: "Un avance concreto para ahora"), symbol: "timer", color: .orange),
    ]

    /// Intenciones sobre el Kit completo.
    static let kit: [AssistantIntent] = [
        AssistantIntent(id: "reduce-scope", title: String(localized: "Necesito reducir el alcance"),
                        detail: String(localized: "Quitar o juntar pasos sin perder el resultado"), symbol: "scissors", color: .orange),
        AssistantIntent(id: "where-left", title: String(localized: "¿Dónde lo dejamos?"),
                        detail: String(localized: "Recuperar el hilo con tu último avance"), symbol: Symbols.note, color: .accentColor),
        AssistantIntent(id: "change-date", title: String(localized: "Quiero cambiar la fecha objetivo"),
                        detail: String(localized: "Ver qué pasos se mueven y por qué"), symbol: Symbols.wantedDate, color: .purple),
        AssistantIntent(id: "still-sense", title: String(localized: "¿Sigue teniendo sentido este plan?"),
                        detail: String(localized: "Revisar el plan con lo que ya sabes"), symbol: "questionmark.circle", color: .green),
    ]

    static let all: [AssistantIntent] = [
        AssistantIntent(id: "less-time", title: String(localized: "Tengo menos tiempo"),
                        detail: String(localized: "Buscar un tramo más pequeño para ahora"), symbol: Symbols.time, color: .blue),
        AssistantIntent(id: "how-to-start", title: String(localized: "No sé cómo empezar"),
                        detail: String(localized: "Aclarar la primera acción"), symbol: "arrow.turn.down.right", color: .accentColor),
        AssistantIntent(id: "missing", title: String(localized: "Me falta algo"),
                        detail: String(localized: "Revisar un bloqueo sin perder lo hecho"), symbol: Symbols.blocked, color: .red),
        AssistantIntent(id: "not-fitting", title: String(localized: "Este paso ya no encaja"),
                        detail: String(localized: "Pensar un cambio que decidirás tú"), symbol: "pencil", color: .purple),
    ]

    /// Mensaje que se envía al modelo; menciona el Kit y el paso para no depender de la memoria.
    func prompt(kit: GoalEntity?, step explicitStep: StepEntity? = nil) -> String {
        let kitName = kit?.title ?? String(localized: "mi Kit")
        let step = explicitStep ?? kit?.nextStep
        let stepText = step.map { String(localized: "«\($0.stepTitle)» (\($0.estimateMinutes) min)") } ?? String(localized: "el siguiente paso")
        switch id {
        case "less-time":
            return String(localized: "Hoy tengo poco tiempo. En \(kitName), ¿qué tramo pequeño de \(stepText) puedo hacer ahora?")
        case "how-to-start":
            return String(localized: "No sé cómo empezar \(stepText) en \(kitName). ¿Cuál sería la primera acción concreta?")
        case "missing":
            let reason = step?.blockedReason.map { " Me frena: \($0)." } ?? ""
            return String(localized: "Me falta algo para avanzar en \(stepText) de \(kitName).\(reason) ¿Cómo puedo seguir sin perder lo hecho?")
        case "split":
            return String(localized: "Ayúdame a dividir \(stepText) de \(kitName) en dos o tres tramos pequeños y concretos.")
        case "fifteen":
            return String(localized: "Tengo 15 minutos. ¿Qué avance concreto puedo hacer ahora en \(stepText) de \(kitName)?")
        case "reduce-scope":
            return String(localized: "Necesito reducir el alcance de \(kitName). ¿Qué pasos podría quitar o juntar sin perder el resultado?")
        case "where-left":
            return String(localized: "¿Dónde lo dejé en \(kitName)? Resume mi último avance y dime el siguiente paso concreto.")
        case "change-date":
            return String(localized: "Quiero cambiar la fecha objetivo de \(kitName). ¿Qué pasos tendría que mover?")
        case "still-sense":
            return String(localized: "¿Sigue teniendo sentido el plan de \(kitName) con lo que llevo hecho? Sé breve.")
        default:
            return String(localized: "Creo que \(stepText) ya no encaja en \(kitName). ¿Qué cambio me propondrías? Lo decidiré yo.")
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
    var intents: [AssistantIntent] = AssistantIntent.all
    var startTitle = String(localized: "¿Por dónde seguimos?")
    var startSubtitle = String(localized: "Elige qué necesitas y revisamos tu siguiente paso.")
    /// Contexto visible (Kit o paso) sobre la conversación.
    var context: String?
    /// Contenido propio tras los mensajes: propuestas, acciones del paso…
    var accessory: AnyView?
    /// Contenido que va justo después de un mensaje concreto (p. ej. la propuesta que lo acompaña).
    var afterMessage: ((ChatMessage) -> AnyView?)? = nil

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
            // Mientras una respuesta «se escribe», la conversación la acompaña hacia abajo.
            .task(id: messages.last?.id) {
                guard let last = messages.last, ChatTyping.isFresh(last) else { return }
                let end = Date.now.addingTimeInterval(ChatTyping.duration(of: last) + 0.6)
                while Date.now < end, !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(250))
                    withAnimation(.smooth(duration: 0.25)) { proxy.scrollTo("bottom", anchor: .bottom) }
                }
            }
        }
        .background(alignment: .top) { BrandGlow() }
        .background(Color(.systemGroupedBackground))
        .safeAreaBar(edge: .bottom) { composer }
    }

    private var start: some View {
        VStack(alignment: .leading, spacing: 12) {
            contextChip
            Text(startTitle)
                .font(.largeTitle.bold())
                .accessibilityAddTraits(.isHeader)
            Text(startSubtitle)
                .foregroundStyle(.secondary)
                .padding(.bottom, 6)
            ForEach(intents) { intent in
                Button { onIntent(intent) } label: { IntentCard(intent: intent) }
                    .buttonStyle(PressableCardStyle())
                    .disabled(isResponding)
                    .accessibilityIdentifier("assistant.intent.\(intent.id)")
            }
            // Con permiso de IA externa responde el asistente del servidor; sin él, el modelo del dispositivo.
            Text(AIConsentManager().hasConsent
                 ? LocalizedStringKey("Responde el asistente de StepKit con un servicio de IA externo. Revisa siempre lo que proponga antes de cambiar tu plan.")
                 : LocalizedStringKey("El asistente usa un servicio de IA externo: te pedirá permiso antes de enviar nada."))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .padding()
    }

    private var conversation: some View {
        LazyVStack(alignment: .leading, spacing: 18) {
            contextChip
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
                if let extra = afterMessage?(message) { extra }
            }
            if isTyping {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Pensando…").foregroundStyle(.secondary)
                }
                .font(.subheadline)
            }
            if let accessory { accessory }
            Color.clear.frame(height: 1).id("bottom")
        }
        .padding()
    }

    @ViewBuilder private var contextChip: some View {
        if let context {
            Label(context, systemImage: Symbols.kits)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.tint)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.accentColor.opacity(0.12), in: .capsule)
        }
    }

    private var composer: some View {
        HStack(spacing: 8) {
            if !intents.isEmpty {
                Menu {
                    ForEach(intents) { intent in
                        Button(intent.title, systemImage: intent.symbol) { onIntent(intent) }
                    }
                } label: {
                    Label("Sugerencias", systemImage: "list.bullet")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.glass)
                .controlSize(.large)
                .disabled(isResponding)
            }

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
    /// Palabras visibles mientras la respuesta «se escribe»; nil = texto completo.
    @State private var shownWords: Int?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var words: [Substring] { message.text.split(separator: " ", omittingEmptySubsequences: false) }

    private var visibleText: String {
        guard let shownWords else { return message.text }
        return words.prefix(shownWords).joined(separator: " ")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Rectangle().fill(Color.accentColor).frame(width: 3).clipShape(.capsule)
            VStack(alignment: .leading, spacing: 6) {
                Text(LocalizedStringKey(visibleText))
                    .font(.body)
                    .textSelection(.enabled)
                    .contentTransition(.opacity)
                Text(String(localized: "\(message.fromServer ? String(localized: "Asistente de StepKit") : String(localized: "Generado en tu dispositivo")) · \(message.timestamp.formatted(date: .omitted, time: .shortened))"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message.text)
        .task(id: message.id) { await typeIn() }
    }

    /// Una respuesta recién llegada aparece poco a poco, como en una conversación.
    private func typeIn() async {
        guard !reduceMotion, ChatTyping.isFresh(message) else { return }
        let total = words.count
        shownWords = 0
        for count in 1...max(total, 1) {
            try? await Task.sleep(for: .milliseconds(ChatTyping.millisecondsPerWord))
            if Task.isCancelled { break }
            withAnimation(.easeOut(duration: 0.15)) { shownWords = count }
        }
        shownWords = nil
    }
}

/// Ritmo con el que se «escriben» las respuestas del asistente.
enum ChatTyping {
    static let millisecondsPerWord = 45

    static func isFresh(_ message: ChatMessage) -> Bool {
        message.sender == .assistant && !message.isError && Date.now.timeIntervalSince(message.timestamp) < 2
    }

    /// Tiempo que tarda en escribirse un mensaje recién llegado (0 si ya estaba).
    static func duration(of message: ChatMessage) -> Double {
        guard isFresh(message) else { return 0 }
        let words = message.text.split(separator: " ").count
        return Double(words * millisecondsPerWord) / 1000
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
                    Text("Puedes seguir con tu Kit. Tu plan y tus avances siguen aquí.")
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
