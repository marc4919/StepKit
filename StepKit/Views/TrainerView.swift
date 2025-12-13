//
//  TrainerView.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on 8/10/25.
//

import SwiftUI
import SwiftData
import UIKit
import FoundationModels

struct ChatMessage: Identifiable, Equatable {
    enum Sender { case user, assistant }
    let id = UUID()
    let sender: Sender
    let text: String
    let timestamp: Date
    
    init(sender: Sender, text: String, timestamp: Date = Date()) {
        self.sender = sender
        self.text = text
        self.timestamp = timestamp
    }
}

struct QuickAction: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let prompt: String
}

// MARK: - Typing Dot Animation
struct TypingDot: View {
    let delay: Double
    @State private var isAnimating = false
    
    // private let accentBlue = Color(red: 0.0, green: 0.48, blue: 1.0)
    
    var body: some View {
        Circle()
            .fill(Color.accentColor.opacity(0.6))
            .frame(width: 8, height: 8)
            .scaleEffect(isAnimating ? 1.0 : 0.5)
            .opacity(isAnimating ? 1.0 : 0.4)
            .animation(
                .easeInOut(duration: 0.6)
                .repeatForever(autoreverses: true)
                .delay(delay),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

struct TrainerView: View {
    // MARK: - SwiftData Query
    @Query(filter: #Predicate<GoalEntity> { !$0.isDeleted }, sort: \GoalEntity.createdAt, order: .reverse)
    private var goalEntities: [GoalEntity]

    /// Indica si el usuario tiene kits (real, basado en SwiftData)
    private var hasKits: Bool { !goalEntities.isEmpty }

    // MARK: - Foundation Model
    private let model = SystemLanguageModel.default
    @State private var assistantService = AssistantService()
    @State private var currentStreamingTask: Task<Void, Never>?

    // MARK: - View State
    @State private var showingFastCreator = false
    @State private var showingResetAlert = false
    @State private var messages: [ChatMessage] = []
    @State private var draft: String = ""
    @State private var showQuickActions: Bool = true
    @State private var isTyping: Bool = false
    @State private var isResponding: Bool = false
    @State private var isLoadingWelcome: Bool = false
    @State private var currentStreamingText: String = ""
    @FocusState private var isInputFocused: Bool
    
    
    // Opciones rápidas
    private let quickActions: [QuickAction] = [
        QuickAction(icon: "flame.fill", title: "Motivación", prompt: "Dame motivación para seguir con mi objetivo"),
        QuickAction(icon: "lightbulb.fill", title: "Consejos", prompt: "Dame consejos para avanzar en mis kits actuales"),
        QuickAction(icon: "questionmark.circle.fill", title: "FAQ", prompt: "¿Cuáles son las preguntas más frecuentes?"),
        QuickAction(icon: "chart.line.uptrend.xyaxis", title: "Progreso", prompt: "¿Cómo voy con mi progreso?")
    ]
    
    // Mensajes de bienvenida
    private let welcomeMessages = [
        "Hola 👋",
        "Soy tu asistente de StepKit.",
        "Puedo ayudarte con tu progreso, motivación o dudas.",
        "¿Qué necesitas?"
    ]

    var body: some View {
        Group {
            switch model.availability {
            case .available:
                if hasKits {
                    chatView
                } else {
                    emptyStateView
                }
            case .unavailable(.deviceNotEligible):
                modelUnavailableView(
                    title: "Dispositivo no compatible",
                    message: "Este dispositivo no es compatible con Apple Intelligence.",
                    showSettingsHint: false
                )
            case .unavailable(.appleIntelligenceNotEnabled):
                modelUnavailableView(
                    title: "Apple Intelligence desactivado",
                    message: "Activa Apple Intelligence en Ajustes para usar el asistente.",
                    showSettingsHint: true
                )
            case .unavailable(.modelNotReady):
                modelUnavailableView(
                    title: "Modelo en preparación",
                    message: "El asistente se está descargando. Inténtalo de nuevo más tarde.",
                    showSettingsHint: false
                )
            case .unavailable:
                modelUnavailableView(
                    title: "Asistente no disponible",
                    message: "El asistente no está disponible en este momento.",
                    showSettingsHint: false
                )
            @unknown default:
                modelUnavailableView(
                    title: "Asistente no disponible",
                    message: "El asistente no está disponible.",
                    showSettingsHint: false
                )
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Asistente")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showingFastCreator) {
            FastCreatorView()
        }
        .alert("Nueva conversación", isPresented: $showingResetAlert) {
            Button("Cancelar", role: .cancel) { }
            Button("Reiniciar", role: .destructive) {
                resetConversation()
            }
        } message: {
            Text("¿Quieres empezar una nueva conversación? Se borrarán los mensajes actuales.")
        }
        .onAppear {
            if messages.isEmpty && hasKits && model.availability == .available && !isLoadingWelcome {
                startWelcomeSequence()
            }
        }
        .onDisappear {
            // Cancelar cualquier tarea de streaming al salir
            currentStreamingTask?.cancel()
        }
    }
    
    // MARK: - Welcome Sequence
    private func startWelcomeSequence() {
        isLoadingWelcome = true
        
        Task { @MainActor in
            for (index, message) in welcomeMessages.enumerated() {
                // Mostrar typing antes de cada mensaje
                withAnimation(.easeInOut(duration: 0.2)) {
                    isTyping = true
                }
                
                // Tiempo de "escritura" (más corto para mensajes cortos)
                let typingDuration: UInt64 = index == 0 ? 600_000_000 : 800_000_000
                try? await Task.sleep(nanoseconds: typingDuration)
                
                // Ocultar typing y añadir mensaje
                withAnimation(.easeInOut(duration: 0.2)) {
                    isTyping = false
                }
                
                try? await Task.sleep(nanoseconds: 100_000_000)
                messages.append(ChatMessage(sender: .assistant, text: message))
                
                // Pausa entre mensajes
                if index < welcomeMessages.count - 1 {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                }
            }
            
            isLoadingWelcome = false
        }
    }
    
    // MARK: - Reset Conversation
    private func resetConversation() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        // Cancelar cualquier streaming en curso
        currentStreamingTask?.cancel()
        currentStreamingTask = nil
        currentStreamingText = ""
        isResponding = false

        withAnimation(.easeInOut(duration: 0.3)) {
            messages.removeAll()
            showQuickActions = true
            isTyping = false
        }

        // Resetear el servicio del asistente
        Task {
            await assistantService.resetConversation(with: buildAssistantContext())
        }

        // Reiniciar secuencia de bienvenida
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            startWelcomeSequence()
        }
    }
    
    // MARK: - Empty State (sin kits)
    @State private var showEmptyStateButton = false

    private var emptyStateView: some View {
        GeometryReader { geometry in
            VStack(spacing: 28) {
                Spacer()
                    .frame(maxHeight: 200)

                // Icono con estilo
                ZStack {
                    Circle()
                        .fill(LinearGradient.accentWithOpacity( 0.3))
                        .frame(width: 80, height: 80)

                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundStyle(LinearGradient.accentGradient)
                        .symbolEffect(.wiggle, options: .repeating)
                }

                // Textos
                VStack(spacing: 12) {
                    Text("Primero, crea tu kit")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text("Para poder ayudarte con tu progreso, necesito que tengas al menos un kit activo.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()
                    .frame(maxHeight: 30)

                // Botón CTA (abajo, igual que en Kits)
                Button {
                    showingFastCreator = true
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                        Text("Crear kit")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(LinearGradient.accentGradient)
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                    .glowShadow()
                }
                .buttonStyle(.plain)
                .opacity(showEmptyStateButton ? 1 : 0)
                .offset(y: showEmptyStateButton ? 0 : 20)

                Spacer()
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background(Color(.systemBackground))
        .contentShape(Rectangle())
        .onTapGesture {
            showingFastCreator = true
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(0.3)) {
                showEmptyStateButton = true
            }
        }
        .onDisappear {
            showEmptyStateButton = false
        }
    }

    // MARK: - Model Unavailable View
    private func modelUnavailableView(title: String, message: String, showSettingsHint: Bool) -> some View {
        VStack(spacing: 24) {
            Spacer()

            // Icono
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.orange.opacity(0.2), Color.red.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "sparkles.slash")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .red.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 12) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                if showSettingsHint {
                    Text("Ajustes → Apple Intelligence y Siri")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            }

            Spacer()
        }
    }

    // MARK: - Build Assistant Context
    private func buildAssistantContext() -> AssistantContext {
        let kitSummaries = goalEntities.map { entity -> KitSummary in
            let completedSteps = entity.steps.filter { $0.isCompleted }.count
            let sortedPendingSteps = entity.steps
                .filter { !$0.isCompleted }
                .sorted { $0.order < $1.order }

            let nextStep = sortedPendingSteps.first
            let dueDate = entity.steps
                .compactMap { $0.suggestedDeadline }
                .max()

            return KitSummary(
                id: entity.id,
                title: entity.planTitle,
                kpi: entity.kpi,
                progress: entity.computedProgress,
                completedSteps: completedSteps,
                totalSteps: entity.steps.count,
                nextStep: nextStep?.stepTitle,
                nextStepEstimateMinutes: nextStep?.estimateMinutes,
                dueDate: dueDate,
                risks: entity.risks
            )
        }

        // Calcular progreso global
        let totalProgress = goalEntities.isEmpty ? 0 :
            goalEntities.map { $0.computedProgress }.reduce(0, +) / Double(goalEntities.count)

        // Construir lista de próximas fechas límite
        let upcomingDeadlines = buildUpcomingDeadlines()

        return AssistantContext(
            kits: kitSummaries,
            totalProgress: totalProgress,
            upcomingDeadlines: upcomingDeadlines,
            today: Date()
        )
    }

    private func buildUpcomingDeadlines() -> [DeadlineInfo] {
        var deadlines: [DeadlineInfo] = []
        let calendar = Calendar.current
        let today = Date()

        for entity in goalEntities {
            for step in entity.steps where !step.isCompleted {
                if let deadline = step.suggestedDeadline {
                    let days = calendar.dateComponents([.day], from: today, to: deadline).day ?? 0
                    if days >= 0 && days <= 14 { // Próximas 2 semanas
                        deadlines.append(DeadlineInfo(
                            stepTitle: step.stepTitle,
                            kitTitle: entity.planTitle,
                            deadline: deadline,
                            daysRemaining: days
                        ))
                    }
                }
            }
        }

        // Ordenar por fecha más próxima
        return deadlines.sorted { $0.deadline < $1.deadline }
    }

    // MARK: - Chat View
    private var chatView: some View {
        VStack(spacing: 0) {
            headerSection
            
            Divider()
            
            messageList
            
            Divider()
            
            // Quick actions fijos encima del input
            if showQuickActions {
                quickActionsSection
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                
                Divider()
            }
            
            inputSection
        }
    }
    
    // MARK: - Header
    private var headerSection: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LinearGradient.accentWithOpacity( 0.25))
                    .frame(width: 44, height: 44)

                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(LinearGradient.accentGradient)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Asistente IA")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Pregúntame lo que necesites")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Botón nueva conversación
            Button {
                showingResetAlert = true
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Image(systemName: "arrow.counterclockwise.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor.opacity(0.7))
            }
            
            // Botón para mostrar/ocultar acciones rápidas
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showQuickActions.toggle()
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Image(systemName: showQuickActions ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor.opacity(0.7))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
    }
    
    // MARK: - Quick Actions
    private var quickActionsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(quickActions) { action in
                    Button {
                        sendQuickAction(action)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: action.icon)
                                .font(.subheadline)
                            Text(action.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color(.tertiarySystemGroupedBackground))
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                        )
                        .foregroundColor(.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.secondarySystemGroupedBackground).opacity(0.5))
    }

    // MARK: - Message List
    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                        let isFirstInGroup = isFirstMessageInGroup(at: index)
                        let isLastInGroup = isLastMessageInGroup(at: index)
                        
                        messageBubble(for: message, showAvatar: isFirstInGroup, isLastInGroup: isLastInGroup)
                            .id(message.id)
                            .transition(.asymmetric(
                                insertion: .move(edge: message.sender == .user ? .trailing : .leading).combined(with: .opacity),
                                removal: .opacity
                            ))
                            .padding(.top, isFirstInGroup ? 8 : 0)
                    }
                    
                    // Typing indicator
                    if isTyping {
                        typingIndicator
                            .id("typing")
                            .transition(.asymmetric(
                                insertion: .move(edge: .leading).combined(with: .opacity),
                                removal: .opacity
                            ))
                            .padding(.top, 8)
                    }
                    
                    // Anchor invisible al final para scroll
                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .onChange(of: messages) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: isTyping) { _, newValue in
                if newValue {
                    scrollToBottom(proxy: proxy)
                }
            }
            .onChange(of: isInputFocused) { _, focused in
                if focused {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        scrollToBottom(proxy: proxy)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    // MARK: - Message Grouping Helpers
    private func isFirstMessageInGroup(at index: Int) -> Bool {
        guard index > 0 else { return true }
        return messages[index].sender != messages[index - 1].sender
    }
    
    private func isLastMessageInGroup(at index: Int) -> Bool {
        guard index < messages.count - 1 else { return true }
        return messages[index].sender != messages[index + 1].sender
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }

    // MARK: - Message Bubble
    @ViewBuilder
    private func messageBubble(for message: ChatMessage, showAvatar: Bool, isLastInGroup: Bool) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.sender == .assistant {
                assistantBubble(message, showAvatar: showAvatar, showTimestamp: isLastInGroup)
                Spacer(minLength: 50)
            } else {
                Spacer(minLength: 50)
                userBubble(message, showAvatar: showAvatar, showTimestamp: isLastInGroup)
            }
        }
    }
    
    private func assistantBubble(_ message: ChatMessage, showAvatar: Bool, showTimestamp: Bool) -> some View {
        HStack(alignment: .top, spacing: 8) {
            // Avatar del asistente (o espacio)
            if showAvatar {
                ZStack {
                    Circle()
                        .fill(LinearGradient.accentWithOpacity( 0.2))
                        .frame(width: 28, height: 28)

                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                }
            } else {
                Color.clear
                    .frame(width: 28, height: 28)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                // Renderizamos Markdown básico (negritas, listas, etc.)
                Text(.init(message.text))
                    .font(.body)
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground))
                    .foregroundStyle(.primary)
                    .clipShape(
                        .rect(
                            topLeadingRadius: showAvatar ? 4 : 16,
                            bottomLeadingRadius: 16,
                            bottomTrailingRadius: 16,
                            topTrailingRadius: 16
                        )
                    )
                
                // Timestamp
                if showTimestamp {
                    Text(message.timestamp, format: .dateTime.hour().minute())
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 4)
                }
            }
        }
    }
    
    private func userBubble(_ message: ChatMessage, showAvatar: Bool, showTimestamp: Bool) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .trailing, spacing: 2) {
                Text(message.text)
                    .font(.body)
                    .padding(12)
                    .background(LinearGradient.accentWithOpacity( 0.25))
                    .foregroundStyle(.primary)
                    .clipShape(
                        // Esquina superior junto al avatar más aguda para simular el “piquito”
                        .rect(
                            topLeadingRadius: 16,
                            bottomLeadingRadius: 16,
                            bottomTrailingRadius: 16,
                            topTrailingRadius: showAvatar ? 4 : 16
                        )
                    )
                
                // Timestamp
                if showTimestamp {
                    Text(message.timestamp, format: .dateTime.hour().minute())
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.trailing, 4)
                }
            }
            
            // Avatar del usuario (o espacio)
            if showAvatar {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.15))
                        .frame(width: 28, height: 28)
                    
                    Image(systemName: "person.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                }
            } else {
                Color.clear
                    .frame(width: 28, height: 28)
            }
        }
    }
    
    // MARK: - Typing Indicator
    private var typingIndicator: some View {
        HStack(alignment: .top, spacing: 8) {
            // Avatar del asistente
            ZStack {
                Circle()
                    .fill(LinearGradient.accentWithOpacity( 0.2))
                    .frame(width: 28, height: 28)

                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.accentColor)
            }
            
            // Burbuja con puntos animados
            HStack(spacing: 4) {
                TypingDot(delay: 0)
                TypingDot(delay: 0.2)
                TypingDot(delay: 0.4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(.secondarySystemGroupedBackground).opacity(0.8))
            .clipShape(
                .rect(
                    topLeadingRadius: 4,
                    bottomLeadingRadius: 16,
                    bottomTrailingRadius: 16,
                    topTrailingRadius: 16
                )
            )
            
            Spacer(minLength: 50)
        }
    }

    // MARK: - Input Section
    private var inputSection: some View {
        HStack(spacing: 12) {
            let isSendDisabled = isResponding || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

            // Campo de texto
            TextField("Escribe un mensaje...", text: $draft, axis: .vertical)
                .font(.body)
                .lineLimit(1...4)
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(isInputFocused ? Color.accentColor.opacity(0.5) : Color(.separator).opacity(0.3), lineWidth: isInputFocused ? 1.5 : 0.5)
                )
                .focused($isInputFocused)
                .submitLabel(.send)
                .onSubmit(sendDraft)
            
            // Botón enviar
            Button(action: sendDraft) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(
                        isSendDisabled
                            ? AnyShapeStyle(Color.gray.opacity(0.4))
                            : AnyShapeStyle(LinearGradient.accentGradient)
                    )
            }
            .disabled(isSendDisabled)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Actions
    private func sendDraft() {
        guard !isResponding else { return }
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        // Ocultar teclado
        isInputFocused = false

        let userMsg = ChatMessage(sender: .user, text: trimmed)
        messages.append(userMsg)
        draft = ""

        // Ocultar quick actions después del primer mensaje
        if showQuickActions {
            withAnimation(.easeInOut(duration: 0.2)) {
                showQuickActions = false
            }
        }

        // Enviar al Foundation Model con streaming
        streamAssistantResponse(message: trimmed, quickAction: nil)
    }

    /// Envía un mensaje al asistente y muestra la respuesta en streaming
    private func streamAssistantResponse(message: String, quickAction: QuickActionType?) {
        // Cancelar cualquier streaming anterior
        currentStreamingTask?.cancel()
        currentStreamingText = ""
        isResponding = true

        // Mostrar typing indicator
        withAnimation(.easeInOut(duration: 0.2)) {
            isTyping = true
        }

        currentStreamingTask = Task { @MainActor in
            defer {
                // Al terminar la tarea (éxito, error o cancelación), liberar el estado de respuesta
                isResponding = false
            }
            do {
                let context = buildAssistantContext()
                let stream = try await assistantService.chat(
                    message: message,
                    context: context,
                    quickAction: quickAction
                )

                // Variables para el mensaje de streaming
                var streamingMessage: ChatMessage?
                var messageIndex: Int?

                // Procesar el stream
                // Foundation Models devuelve contenido acumulado, no deltas
                for try await cumulativeContent in stream {
                    // Verificar si la tarea fue cancelada
                    if Task.isCancelled { break }

                    // Si es el primer contenido y aún no hemos creado el mensaje
                    if streamingMessage == nil && !cumulativeContent.isEmpty {
                        // Ocultar typing indicator cuando empezamos a recibir contenido
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isTyping = false
                        }
                        
                        // Crear mensaje del asistente con el primer contenido
                        streamingMessage = ChatMessage(sender: .assistant, text: cumulativeContent)
                        messages.append(streamingMessage!)
                        messageIndex = messages.count - 1
                        currentStreamingText = cumulativeContent
                    } else if let index = messageIndex {
                        // Actualizar el mensaje existente con el contenido acumulado
                        currentStreamingText = cumulativeContent
                        messages[index] = ChatMessage(
                            sender: .assistant,
                            text: currentStreamingText,
                            timestamp: streamingMessage!.timestamp
                        )
                    }
                }

                // Si no se recibió ningún contenido, ocultar el typing indicator
                if streamingMessage == nil {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isTyping = false
                    }
                }

                // Limpiar estado de streaming
                currentStreamingText = ""

            } catch let error as AssistantError {
                await handleAssistantError(error)
            } catch {
                await handleAssistantError(.unknown(error.localizedDescription))
            }
        }
    }

    /// Maneja errores del asistente
    private func handleAssistantError(_ error: AssistantError) async {
        withAnimation(.easeInOut(duration: 0.2)) {
            isTyping = false
        }

        currentStreamingText = ""
        isResponding = false

        // Si el contexto se excedió, resetear la sesión
        if case .contextWindowExceeded = error {
            await assistantService.resetConversation(with: buildAssistantContext())
        }

        // Mostrar mensaje de error como respuesta del asistente
        let errorMessage = ChatMessage(
            sender: .assistant,
            text: error.localizedDescription
        )
        messages.append(errorMessage)

        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
    
    private func sendQuickAction(_ action: QuickAction) {
        let userMsg = ChatMessage(sender: .user, text: action.prompt)
        messages.append(userMsg)

        // Ocultar quick actions
        withAnimation(.easeInOut(duration: 0.2)) {
            showQuickActions = false
        }

        // Convertir el título de la acción a QuickActionType
        let quickActionType: QuickActionType?
        switch action.title {
        case "Motivación":
            quickActionType = .motivation
        case "Consejos":
            quickActionType = .tips
        case "FAQ":
            quickActionType = .faq
        case "Progreso":
            quickActionType = .progress
        default:
            quickActionType = nil
        }

        // Si es la acción de consejos y todos los kits están completados, responder localmente
        if quickActionType == .tips && areAllKitsCompleted() {
            // Simular que “piensa” mostrando el typing indicator un momento
            withAnimation(.easeInOut(duration: 0.2)) {
                isTyping = true
            }
            isResponding = true
            
            Task { @MainActor in
                // Breve pausa para la animación de puntos
                try? await Task.sleep(nanoseconds: 700_000_000)
                
                withAnimation(.easeInOut(duration: 0.2)) {
                    isTyping = false
                }
                isResponding = false
                
                let assistantMsg = ChatMessage(
                    sender: .assistant,
                    text: """
                    ¡Genial! Ahora mismo todos tus kits están completados. 🎉
                    Es un buen momento para definir nuevas metas o actualizar tus objetivos actuales para seguir creciendo.
                    """
                )
                messages.append(assistantMsg)
            }
            return
        }

        // Si es la acción de FAQ, responder localmente con dos bloques
        if quickActionType == .faq {
            withAnimation(.easeInOut(duration: 0.2)) {
                isTyping = true
            }
            isResponding = true
            
            Task { @MainActor in
                // Breve pausa para la animación de puntos
                try? await Task.sleep(nanoseconds: 650_000_000)
                
                withAnimation(.easeInOut(duration: 0.2)) {
                    isTyping = false
                }
                isResponding = false
                
                let assistantMsg = ChatMessage(
                    sender: .assistant,
                    text: """
                    **Preguntas sobre uso de la app**
                    - ¿Cómo crear un kit desde la pestaña Kits?
                    - ¿Cómo crear un kit con una fecha desde Calendario?
                    - ¿Cómo encontrar kits desde el buscador?
                    - ¿Qué puedo hacer en el tab de Perfil?

                    **Preguntas sobre los kits**
                    - ¿Qué paso me falta para completar mi kit?
                    - ¿Tengo tiempo suficiente para completar el kit?
                    - ¿Puedo adelantar el kit?
                    - ¿Hay otro kit que pueda combinar con el actual?
                    - ¿Cuánto tiempo me tomará completar el kit?
                    """
                )
                messages.append(assistantMsg)
            }
            return
        }

        // Enviar al Foundation Model con streaming cuando hay kits pendientes
        streamAssistantResponse(message: action.prompt, quickAction: quickActionType)
    }

    /// Verifica si todos los kits tienen sus pasos completados
    private func areAllKitsCompleted() -> Bool {
        guard !goalEntities.isEmpty else { return false }
        return goalEntities.allSatisfy { entity in
            entity.steps.allSatisfy { $0.isCompleted }
        }
    }
}

#Preview("Con kits") {
    NavigationStack {
        TrainerView()
    }
}

#Preview("Sin kits") {
    NavigationStack {
        TrainerView()
    }
}
