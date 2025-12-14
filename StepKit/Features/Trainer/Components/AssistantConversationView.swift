//
//  AssistantConversationView.swift
//  StepKit
//
//  Extracted from TrainerView.swift
//

import SwiftUI

struct AssistantConversationView: View {
    @Binding var messages: [ChatMessage]
    @Binding var draft: String
    @Binding var showQuickActions: Bool
    @Binding var isTyping: Bool
    @Binding var isResponding: Bool
    
    var isInputFocused: FocusState<Bool>.Binding
    
    let quickActions: [QuickAction]
    let onSendMessage: () -> Void
    let onQuickAction: (QuickAction) -> Void
    let onResetConversation: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            
            Divider()
            
            messageList
            
            Divider()
            
            // Quick actions fijos encima del input
            if showQuickActions {
                QuickActionSuggestions(actions: quickActions, onActionTapped: onQuickAction)
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
                    .foregroundStyle(.primary)
                
                Text("Pregúntame lo que necesites")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Botón nueva conversación
            Button {
                onResetConversation()
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
    
    // MARK: - Message List
    
    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(messages.enumerated(), id: \.element.id) { index, message in
                        let isFirstInGroup = isFirstMessageInGroup(at: index)
                        let isLastInGroup = isLastMessageInGroup(at: index)
                        
                        ChatMessageBubble(
                            message: message,
                            showAvatar: isFirstInGroup,
                            isLastInGroup: isLastInGroup
                        )
                        .id(message.id)
                        .transition(.asymmetric(
                            insertion: .move(edge: message.sender == .user ? .trailing : .leading).combined(with: .opacity),
                            removal: .opacity
                        ))
                        .padding(.top, isFirstInGroup ? 8 : 0)
                    }
                    
                    // Typing indicator
                    if isTyping {
                        TypingIndicatorBubble()
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
            .onChange(of: isInputFocused.wrappedValue) { _, focused in
                if focused {
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(150))
                        scrollToBottom(proxy: proxy)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
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
                        .stroke(isInputFocused.wrappedValue ? Color.accentColor.opacity(0.5) : Color(.separator).opacity(0.3), lineWidth: isInputFocused.wrappedValue ? 1.5 : 0.5)
                )
                .focused(isInputFocused)
                .submitLabel(.send)
                .onSubmit(onSendMessage)
            
            // Botón enviar
            Button(action: onSendMessage) {
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
    
    // MARK: - Helpers
    
    private func isFirstMessageInGroup(at index: Int) -> Bool {
        guard index > 0 else { return true }
        return messages[index].sender != messages[index - 1].sender
    }
    
    private func isLastMessageInGroup(at index: Int) -> Bool {
        guard index < messages.count - 1 else { return true }
        return messages[index].sender != messages[index + 1].sender
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(50))
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }
}
