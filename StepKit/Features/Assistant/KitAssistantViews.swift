//
//  KitAssistantViews.swift
//  StepKit
//
//  Asistente del Kit: lista de conversaciones por asunto, conversación (desde el Kit
//  o desde un paso) y tarjeta de propuesta con cambio, impacto y Aceptar/Descartar.
//

import SwiftUI
import SwiftData

// MARK: - Lista del Kit

struct KitAssistantHubView: View {
    let kit: GoalEntity
    @State private var store = KitAssistantStore.shared
    @State private var opened: OpenedConversation?

    private struct OpenedConversation: Identifiable, Hashable {
        let id = UUID()
        let conversation: KitConversation
        let intent: AssistantIntent.ID?
        static func == (a: Self, b: Self) -> Bool { a.id == b.id }
        func hash(into hasher: inout Hasher) { hasher.combine(id) }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    IconChip(symbol: Symbols.assistant, color: .accentColor, size: 44)
                    Text("Asistente del Kit").font(.largeTitle.bold())
                    Text("Conversaciones sobre \(kit.title). Cualquier cambio en el plan llega como propuesta que tú decides.")
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)
            }
            Section("Empezar una conversación") {
                // Conversación libre: escribir directamente, sin elegir antes un tema.
                Button {
                    let conversation = store.newConversation(kit: kit, title: String(localized: "Conversación sobre el Kit"))
                    opened = OpenedConversation(conversation: conversation, intent: nil)
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Escribir al asistente").foregroundStyle(.primary)
                            Text("Pregunta lo que quieras sobre este Kit").font(.caption).foregroundStyle(.secondary)
                        }
                    } icon: {
                        IconChip(symbol: "square.and.pencil", color: .accentColor, size: 30)
                    }
                    .navigationRow()
                }
                .buttonStyle(ListRowButtonStyle())
                .listRowInsets(EdgeInsets())
                .accessibilityIdentifier("kitAssistant.freeChat")
                ForEach(AssistantIntent.kit) { intent in
                    Button {
                        let conversation = store.newConversation(kit: kit, title: intent.title)
                        opened = OpenedConversation(conversation: conversation, intent: intent.id)
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(intent.title).foregroundStyle(.primary)
                                Text(intent.detail).font(.caption).foregroundStyle(.secondary)
                            }
                        } icon: {
                            IconChip(symbol: intent.symbol, color: intent.color, size: 30)
                        }
                        .navigationRow()
                    }
                    .buttonStyle(ListRowButtonStyle())
                    .listRowInsets(EdgeInsets())
                        .accessibilityIdentifier("kitAssistant.intent.\(intent.id)")
                }
            }
            Section("Conversaciones") {
                // Una conversación libre que se abrió y no se usó no aparece en la lista.
                let conversations = store.conversations(for: kit.id)
                    .filter { !$0.viewModel.messages.isEmpty || !$0.proposals.isEmpty }
                if conversations.isEmpty {
                    Text("Aún no hay conversaciones. Las que abras desde un paso también aparecerán aquí.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                ForEach(conversations) { conversation in
                    Button {
                        opened = OpenedConversation(conversation: conversation, intent: nil)
                    } label: {
                        ConversationRow(conversation: conversation).navigationRow()
                    }
                    .buttonStyle(ListRowButtonStyle())
                    .listRowInsets(EdgeInsets())
                    }
            }
        }
        .scrollContentBackground(.hidden)
        .readableContentWidth()
        .background(alignment: .top) { BrandGlow() }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(kit.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $opened) { item in
            KitAssistantChatView(kit: kit, conversation: item.conversation, initialIntent: item.intent)
        }
    }
}

private extension View {
    /// Fila que lleva a otra pantalla: toda la fila responde al toque y lleva el chevron de navegación.
    func navigationRow() -> some View {
        HStack(spacing: 8) {
            self.frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .contentShape(.rect)
    }
}

private struct ConversationRow: View {
    let conversation: KitConversation

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            IconChip(symbol: conversation.stepID == nil ? Symbols.kits : "list.bullet",
                     color: conversation.stepID == nil ? .accentColor : .purple, size: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(conversation.title).font(.headline).foregroundStyle(.primary).lineLimit(1)
                if let preview = conversation.preview {
                    Text(preview).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                }
                HStack(spacing: 6) {
                    if conversation.stepID != nil {
                        Text("Vinculada al paso")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.purple)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.12), in: .capsule)
                    }
                    if conversation.pendingProposalCount > 0 {
                        Text(conversation.pendingProposalCount == 1 ? String(localized: "Propuesta pendiente")
                             : String(localized: "\(conversation.pendingProposalCount) propuestas pendientes"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.12), in: .capsule)
                    }
                    Text(conversation.lastActivity.formatted(.relative(presentation: .named)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Conversación

struct KitAssistantChatView: View {
    let kit: GoalEntity
    @Bindable var conversation: KitConversation
    var initialIntent: AssistantIntent.ID?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.syncManager) private var syncManager
    @Environment(\.apiClient) private var apiClient: any APIClientProtocol
    @Environment(AuthManager.self) private var authManager
    @FocusState private var inputFocused: Bool
    @State private var didSendInitial = false
    /// Lo que se iba a enviar mientras se pide el permiso de IA externa.
    @State private var pendingSend: PendingSend?
    /// El permiso se pide una vez por conversación; si dice «Ahora no», responde el dispositivo.
    @State private var askedConsent = false

    private enum PendingSend: Identifiable {
        case draft(String), intent(AssistantIntent)
        var id: String {
            switch self {
            case .draft(let text): "draft-\(text)"
            case .intent(let intent): "intent-\(intent.id)"
            }
        }
    }

    private var step: StepEntity? {
        conversation.stepID.flatMap { id in kit.orderedActiveSteps.first { $0.id == id } }
    }

    private var intents: [AssistantIntent] { step == nil ? AssistantIntent.kit : AssistantIntent.step }

    var body: some View {
        @Bindable var vm = conversation.viewModel
        AssistantHomeView(
            messages: vm.messages,
            draft: $vm.draft,
            isTyping: vm.isTyping,
            isResponding: vm.isResponding,
            isInputFocused: $inputFocused,
            onSend: { sendDraft() },
            onIntent: send,
            onRetry: { vm.retryLast(goals: [kit]) },
            // En el Kit las opciones ya están en la pantalla anterior; aquí solo se escribe.
            intents: step == nil ? [] : intents,
            startTitle: step == nil ? String(localized: "¿En qué te ayudo con el Kit?") : String(localized: "¿Qué te ayudaría con este paso?"),
            startSubtitle: step == nil
                ? String(localized: "Escribe abajo lo que necesites. Si algo cambia el plan, te llega como propuesta y decides tú.")
                : String(localized: "Desde aquí nada cambia el resto del Kit sin una propuesta que tú aceptes."),
            context: step.map { String(localized: "Paso \(kit.position(of: $0)) · \($0.stepTitle)") } ?? kit.title,
            accessory: AnyView(accessory),
            afterMessage: { message in
                let anchored = conversation.proposals.filter { $0.anchorMessageID == message.id }
                guard !anchored.isEmpty else { return nil }
                // La propuesta llega cuando la respuesta termina de escribirse.
                return AnyView(DelayedReveal(delay: ChatTyping.duration(of: message) + 0.2) {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(anchored) { proposalCard($0) }
                    }
                })
            }
        )
        .readableContentWidth(720)
        .navigationTitle(step == nil ? conversation.title : String(localized: "Ayuda del paso"))
        .navigationBarTitleDisplayMode(.inline)
        .hidesTabBarSmoothly()
        .sheet(item: $pendingSend) { pending in
            AIConsentView(purpose: .assistant) { _ in
                askedConsent = true
                pendingSend = nil
                switch pending {
                case .draft(let text): deliver(text)
                case .intent(let intent): deliver(intent)
                }
            }
            .interactiveDismissDisabled()
        }
        .onAppear {
            // Conversación libre y vacía: el teclado ya listo para escribir.
            if initialIntent == nil, vm.messages.isEmpty, conversation.proposals.isEmpty {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(450))
                    inputFocused = true
                }
            }
            guard !didSendInitial, let id = initialIntent,
                  let intent = intents.first(where: { $0.id == id }) else { return }
            didSendInitial = true
            send(intent)
        }
    }

    private func proposalCard(_ proposal: PlanProposal) -> some View {
        ProposalCard(proposal: proposal) {
            proposal.accept(in: kit, context: modelContext)
            // El cambio queda en «Tu recorrido» del Kit.
            let lines = proposal.changes.map { change -> String in
                if let to = change.to {
                    return "\(change.stepLabel): \(to.formatted(.dateTime.day().month(.abbreviated)))"
                }
                return [change.stepLabel, change.detail].compactMap { $0 }.joined(separator: ": ")
            }
            try? ProgressLog.addAssistantChange(title: proposal.title, lines: lines, kit: kit, context: modelContext)
            syncManager?.handleDataChange()
        } onDiscard: {
            proposal.state = .discarded
        }
    }

    @ViewBuilder private var accessory: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Solo las propuestas sin mensaje de referencia (p. ej. de ejemplo) van al final.
            let messageIDs = Set(conversation.viewModel.messages.map(\.id))
            ForEach(conversation.proposals.filter { $0.anchorMessageID.map { !messageIDs.contains($0) } ?? true }) {
                proposalCard($0)
            }
            if let step, step.isBlocked,
               conversation.viewModel.messages.contains(where: { $0.text == String(localized: "Me falta algo") }) {
                ResolveBlockCard(step: step) {
                    try? ProgressLog.resolveBlock(for: step, context: modelContext)
                    syncManager?.handleDataChange()
                }
            }
        }
    }

    private var hasConsent: Bool { AIConsentManager().hasConsent }

    /// Mensaje escrito. Sin permiso de IA externa se pide una vez; sin él responde el dispositivo.
    private func sendDraft() {
        let vm = conversation.viewModel
        let text = vm.draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !vm.isResponding else { return }
        guard hasConsent || askedConsent else {
            inputFocused = false
            pendingSend = .draft(text)
            return
        }
        vm.draft = ""
        deliver(text)
    }

    private func send(_ intent: AssistantIntent) {
        guard !conversation.viewModel.isResponding else { return }
        guard hasConsent || askedConsent else {
            pendingSend = .intent(intent)
            return
        }
        deliver(intent)
    }

    /// Con permiso va al asistente del servidor; si no hay permiso o el servidor no responde, al modelo local.
    private func deliver(_ text: String) {
        let vm = conversation.viewModel
        vm.draft = ""
        guard hasConsent else {
            vm.draft = text
            vm.sendDraft(goals: [kit])
            return
        }
        vm.messages.append(ChatMessage(sender: .user, text: text))
        Task {
            let handled = await KitAssistant.ask(.message, message: text, kit: kit, step: step,
                                                 conversation: conversation, context: modelContext,
                                                 apiClient: apiClient, token: authManager.token)
            if !handled {
                vm.messages.removeLast()
                vm.draft = text
                vm.sendDraft(goals: [kit])
            }
        }
    }

    private func deliver(_ intent: AssistantIntent) {
        let vm = conversation.viewModel
        guard hasConsent else {
            answerLocally(intent)
            return
        }
        vm.messages.append(ChatMessage(sender: .user, text: intent.title))
        Task {
            let handled = await KitAssistant.ask(.message, message: intent.title, kit: kit, step: step,
                                                 conversation: conversation, context: modelContext,
                                                 apiClient: apiClient, token: authManager.token)
            guard !handled else { return }
            vm.messages.removeLast()
            answerLocally(intent)
        }
    }

    /// Sin asistente en el servidor: modelo del dispositivo y propuestas locales.
    private func answerLocally(_ intent: AssistantIntent) {
        let vm = conversation.viewModel
        vm.sendIntent(title: intent.title, prompt: intent.prompt(kit: kit, step: step), goals: [kit])
        switch intent.id {
        case "not-fitting":
            if let step, let proposal = PlanProposalBuilder.moveStep(step, in: kit) {
                conversation.add(proposal)
            }
        case "change-date":
            if let proposal = PlanProposalBuilder.shiftTarget(of: kit) {
                conversation.add(proposal)
            }
        default:
            break
        }
    }
}

// MARK: - Tarjetas

struct ProposalCard: View {
    let proposal: PlanProposal
    let onAccept: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Eyebrow(text: String(localized: "Propuesta"), color: .orange)
                Spacer()
                switch proposal.state {
                case .accepted:
                    Label("Aplicada", systemImage: "checkmark.circle.fill").font(.caption.weight(.semibold)).foregroundStyle(.green)
                case .discarded:
                    Label("Descartada", systemImage: "xmark.circle").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                case .superseded:
                    Label("Sustituida por otra más reciente", systemImage: "arrow.uturn.down.circle")
                        .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                case .pending:
                    EmptyView()
                }
            }
            Text(proposal.title).font(.headline)
            // Las propuestas ya decididas o sustituidas se pliegan para que la conversación se lea bien.
            if proposal.state == .pending {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(proposal.changes) { change in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: change.symbol)
                            .foregroundStyle(change.to != nil ? MetaTint.date : Color.accentColor)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(change.stepLabel).font(.subheadline.weight(.medium))
                            if let to = change.to {
                                HStack(spacing: 6) {
                                    if let from = change.from {
                                        Text(from.formatted(.dateTime.day().month(.abbreviated)))
                                            .strikethrough()
                                            .foregroundStyle(.secondary)
                                        Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.secondary)
                                    }
                                    Text(to.formatted(.dateTime.day().month(.abbreviated)))
                                        .fontWeight(.semibold)
                                        .foregroundStyle(MetaTint.date)
                                }
                                .font(.caption)
                            }
                            if let detail = change.detail, !detail.isEmpty {
                                Text(detail).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            Label(proposal.impact, systemImage: "info.circle")
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            if proposal.state == .pending {
                HStack(spacing: 10) {
                    Button(action: onAccept) {
                        Text("Aceptar").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("proposal.accept")
                    Button(action: onDiscard) {
                        Text("Descartar").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("proposal.discard")
                }
                .controlSize(.large)
                Text(proposal.changes.count > 1
                     ? String(localized: "Los \(proposal.changes.count) cambios se aplican o se descartan juntos para que el plan siga en orden.")
                     : String(localized: "Solo cambia este paso."))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color.orange.opacity(proposal.state == .pending ? 0.08 : 0.04), in: .rect(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.orange.opacity(proposal.state == .pending ? 0.25 : 0.12)))
        .animation(.default, value: proposal.state)
    }
}

private struct ResolveBlockCard: View {
    let step: StepEntity
    let onResolve: () -> Void

    var body: some View {
        TintCard(tint: .red, strength: 0.08) {
            HStack(alignment: .top, spacing: 12) {
                IconChip(symbol: Symbols.blocked, color: .red)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Paso bloqueado").font(.headline)
                    Text(step.blockedReason ?? "").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Button(action: onResolve) {
                Text("Ya está resuelto: resolver bloqueo").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("assistant.resolveBlock")
        }
    }
}
