//
//  TrainerViewModel.swift
//  StepKit
//
//  Created by Assistant on 2024-12-13.
//

import SwiftUI
import SwiftData
import FoundationModels
import UIKit

@Observable
@MainActor
final class TrainerViewModel {
    
    // MARK: - Dependencies
    
    private let assistantService = AssistantService()
    private let model = SystemLanguageModel.default
    
    // MARK: - Published State
    
    var messages: [ChatMessage] = []
    var draft: String = ""
    var showQuickActions: Bool = true
    var isTyping: Bool = false
    var isResponding: Bool = false
    var isLoadingWelcome: Bool = false
    var currentStreamingText: String = ""
    
    // UI State
    var showingKitCreator: Bool = false
    var showingResetAlert: Bool = false
    
    // MARK: - Internal State
    
    private var currentStreamingTask: Task<Void, Never>?
    private var welcomeTask: Task<Void, Never>?
    
    // MARK: - Constants
    
    let quickActions: [QuickAction] = [
        QuickAction(icon: "flame.fill", title: String(localized: "Motivación"), prompt: String(localized: "Dame motivación para seguir con mi objetivo")),
        QuickAction(icon: "lightbulb.fill", title: String(localized: "Consejos"), prompt: String(localized: "Dame consejos para avanzar en mis kits actuales")),
        QuickAction(icon: "questionmark.circle.fill", title: "FAQ", prompt: String(localized: "¿Cuáles son las preguntas más frecuentes?")),
        QuickAction(icon: "chart.line.uptrend.xyaxis", title: String(localized: "Progreso"), prompt: String(localized: "¿Cómo voy con mi progreso?"))
    ]
    
    private let welcomeMessages = [
        String(localized: "Hola 👋 Soy tu asistente de StepKit. Puedo ayudarte con tu progreso, motivación o dudas. ¿Qué necesitas?")
    ]
    
    // MARK: - Computed Properties
    
    var isModelAvailable: Bool {
        model.availability == .available
    }

    var modelAvailability: SystemLanguageModel.Availability {
        model.availability
    }
    

    
    // MARK: - Public Methods
    
    /// v4.4: la pantalla de inicio con intenciones sustituye al mensaje de bienvenida.
    func onAppear(goals: [GoalEntity]) {}

    /// Último mensaje enviado al modelo, para reintentar tras un error.
    private var lastPrompt: String?

    func retryLast(goals: [GoalEntity]) {
        guard !isResponding, let prompt = lastPrompt else { return }
        if messages.last?.isError == true { messages.removeLast() }
        streamAssistantResponse(message: prompt, quickAction: nil, goals: goals)
    }

    /// Envía una intención: el usuario ve el título; el modelo recibe el contexto del paso.
    func sendIntent(title: String, prompt: String, goals: [GoalEntity]) {
        guard !isResponding else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        messages.append(ChatMessage(sender: .user, text: title))
        showQuickActions = false
        streamAssistantResponse(message: prompt, quickAction: nil, goals: goals)
    }
    
    func onDisappear() {
        currentStreamingTask?.cancel()
        welcomeTask?.cancel()
    }
    
    func startWelcomeSequence() {
        welcomeTask?.cancel()
        isLoadingWelcome = true
        
        welcomeTask = Task { @MainActor in
            // Breve pausa inicial
            try? await Task.sleep(nanoseconds: 300_000_000)
            
            if Task.isCancelled { return }
            
            // Mostrar typing
            withAnimation(.easeInOut(duration: 0.2)) {
                isTyping = true
            }
            
            // Tiempo de "escritura" rápido
            try? await Task.sleep(nanoseconds: 800_000_000)
            
            if Task.isCancelled { return }
            
            // Ocultar typing y mostrar mensaje
            withAnimation(.easeInOut(duration: 0.2)) {
                isTyping = false
            }
            
            try? await Task.sleep(nanoseconds: 100_000_000)
            
            if Task.isCancelled { return }
            
            if let message = welcomeMessages.first {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    messages.append(ChatMessage(sender: .assistant, text: message))
                }
            }
            
            isLoadingWelcome = false
        }
    }
    
    func resetConversation(goals: [GoalEntity]) {
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
            await assistantService.resetConversation(with: AssistantContextBuilder.build(from: goals))
        }

    }
    
    func sendDraft(goals: [GoalEntity]) {
        // Cancelar bienvenida si el usuario interactúa
        welcomeTask?.cancel()
        isLoadingWelcome = false
        if isTyping && messages.isEmpty { isTyping = false }

        guard !isResponding else { return }
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()

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
        streamAssistantResponse(message: trimmed, quickAction: nil, goals: goals)
    }
    
    func sendQuickAction(_ action: QuickAction, goals: [GoalEntity]) {
        // Cancelar bienvenida si el usuario interactúa
        welcomeTask?.cancel()
        isLoadingWelcome = false
        if isTyping && messages.isEmpty { isTyping = false }

        let userMsg = ChatMessage(sender: .user, text: action.prompt)
        messages.append(userMsg)

        // Ocultar quick actions
        withAnimation(.easeInOut(duration: 0.2)) {
            showQuickActions = false
        }

        // Convertir el título de la acción a QuickActionType
        let quickActionType: QuickActionType?
        switch action.title {
        case String(localized: "Motivación"):
            quickActionType = .motivation
        case String(localized: "Consejos"):
            quickActionType = .tips
        case "FAQ":
            quickActionType = .faq
        case String(localized: "Progreso"):
            quickActionType = .progress
        default:
            quickActionType = nil
        }

        // Si es la acción de consejos y todos los kits están completados, responder localmente
        if quickActionType == .tips && AssistantContextBuilder.areAllKitsCompleted(goals: goals) {
            simulateLocalResponse(
                text: """
                ¡Genial! Ahora mismo todos tus kits están completados. 🎉
                Es un buen momento para definir nuevas metas o actualizar tus objetivos actuales para seguir creciendo.
                """
            )
            return
        }

        // Si es la acción de FAQ, responder localmente con dos bloques
        if quickActionType == .faq {
            simulateLocalResponse(
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
            return
        }

        // Enviar al Foundation Model con streaming cuando hay kits pendientes
        streamAssistantResponse(message: action.prompt, quickAction: quickActionType, goals: goals)
    }
    
    // MARK: - Private Helpers
    
    private func simulateLocalResponse(text: String) {
        // Simular que "piensa" mostrando el typing indicator un momento
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
                text: text
            )
            messages.append(assistantMsg)
        }
    }
    
    private func streamAssistantResponse(message: String, quickAction: QuickActionType?, goals: [GoalEntity]) {
        lastPrompt = message
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
                let context = AssistantContextBuilder.build(from: goals)
                let stream = try await assistantService.chat(
                    message: message,
                    context: context,
                    quickAction: quickAction
                )

                // Variables para el mensaje de streaming
                var streamingMessage: ChatMessage?
                var messageIndex: Int?

                // Procesar el stream
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
                await handleAssistantError(error, goals: goals)
            } catch {
                await handleAssistantError(.unknown(error.localizedDescription), goals: goals)
            }
        }
    }
    
    private func handleAssistantError(_ error: AssistantError, goals: [GoalEntity]) async {
        withAnimation(.easeInOut(duration: 0.2)) {
            isTyping = false
        }

        currentStreamingText = ""
        isResponding = false

        // Si el contexto se excedió, resetear la sesión
        if case .contextWindowExceeded = error {
            await assistantService.resetConversation(with: AssistantContextBuilder.build(from: goals))
        }

        // Mostrar mensaje de error como respuesta del asistente
        let errorMessage = ChatMessage(
            sender: .assistant,
            text: error.localizedDescription,
            isError: true
        )
        messages.append(errorMessage)

        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}
