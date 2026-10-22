//
//  ChatMessageBubble.swift
//  StepKit
//
//  Extracted from TrainerView.swift
//

import SwiftUI

// MARK: - Chat Message Model

struct ChatMessage: Identifiable, Equatable {
    enum Sender { case user, assistant }
    let id = UUID()
    let sender: Sender
    let text: String
    let timestamp: Date
    /// La respuesta no se pudo generar; `text` es el detalle técnico.
    var isError = false
    /// Respuesta del asistente del servidor; si es false, la generó el modelo del dispositivo.
    var fromServer = false
    
    init(sender: Sender, text: String, timestamp: Date = Date(), isError: Bool = false, fromServer: Bool = false) {
        self.sender = sender
        self.text = text
        self.timestamp = timestamp
        self.isError = isError
        self.fromServer = fromServer
    }
}

// MARK: - Typing Dot Animation

struct TypingDot: View {
    let delay: Double
    @State private var isAnimating = false
    
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

// MARK: - Message Bubble View

struct ChatMessageBubble: View {
    let message: ChatMessage
    let showAvatar: Bool
    let isLastInGroup: Bool
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.sender == .assistant {
                assistantBubble
                Spacer(minLength: 50)
            } else {
                Spacer(minLength: 50)
                userBubble
            }
        }
    }
    
    // MARK: - Assistant Bubble
    
    private var assistantBubble: some View {
        HStack(alignment: .top, spacing: 8) {
            // Avatar del asistente (o espacio)
            if showAvatar {
                ZStack {
                    Circle()
                        .fill(LinearGradient.accentWithOpacity( 0.2))
                        .frame(width: 28, height: 28)
                        .accessibilityHidden(true)

                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)
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
                if isLastInGroup {
                    Text(message.timestamp, format: .dateTime.hour().minute())
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 4)
                }
            }
        }
    }
    
    // MARK: - User Bubble
    
    private var userBubble: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .trailing, spacing: 2) {
                Text(message.text)
                    .font(.body)
                    .padding(12)
                    .background(LinearGradient.accentWithOpacity( 0.25))
                    .foregroundStyle(.primary)
                    .clipShape(
                        // Esquina superior junto al avatar más aguda para simular el "piquito"
                        .rect(
                            topLeadingRadius: 16,
                            bottomLeadingRadius: 16,
                            bottomTrailingRadius: 16,
                            topTrailingRadius: showAvatar ? 4 : 16
                        )
                    )
                
                // Timestamp
                if isLastInGroup {
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
                        .accessibilityHidden(true)
                    
                    Image(systemName: "person.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)
                }
            } else {
                Color.clear
                    .frame(width: 28, height: 28)
            }
        }
    }
}

// MARK: - Typing Indicator

struct TypingIndicatorBubble: View {
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Avatar del asistente
            ZStack {
                Circle()
                    .fill(LinearGradient.accentWithOpacity( 0.2))
                    .frame(width: 28, height: 28)
                    .accessibilityHidden(true)

                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
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
        .accessibilityLabel("El asistente está escribiendo")
        .accessibilityValue("Esperando respuesta")
    }
}
