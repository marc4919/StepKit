//
//  TrainerView.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on 8/10/25.
//

import SwiftUI

struct ChatMessage: Identifiable, Equatable {
    enum Sender { case user, assistant }
    let id = UUID()
    let sender: Sender
    let text: String
}

struct TrainerView: View {
    @State private var messages: [ChatMessage] = [
        ChatMessage(sender: .assistant, text: "Hi! I’m your AI trainer. How can I help you today?")
    ]
    @State private var draft: String = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            messageList
            Divider()
            inputBar
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
        }
        .navigationTitle("Trainer")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Ensure list starts at bottom
            scrollToBottom(animated: false)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.title2)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("AI Chat")
                    .font(.headline)
                Text("Ask questions, get guidance")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(messages) { message in
                        messageBubble(for: message)
                            .id(message.id)
                            .transition(.move(edge: message.sender == .user ? .trailing : .leading).combined(with: .opacity))
                            .animation(.spring(duration: 0.35), value: messages)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .onChange(of: messages) { _, _ in
                withAnimation {
                    if let last = messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            .onChange(of: isInputFocused) { _, _ in
                // Keep latest visible when keyboard appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    withAnimation {
                        if let last = messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func messageBubble(for message: ChatMessage) -> some View {
        HStack(alignment: .bottom) {
            if message.sender == .assistant {
                // Assistant on the left
                bubbleView(message)
                Spacer(minLength: 40)
            } else {
                // User on the right
                Spacer(minLength: 40)
                bubbleView(message)
            }
        }
    }

    @ViewBuilder
    private func bubbleView(_ message: ChatMessage) -> some View {
        let isUser = message.sender == .user
        HStack(alignment: .bottom, spacing: 6) {
            if !isUser {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 2)
            }
            Text(message.text)
                .padding(12)
                .background(isUser ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.15))
                .foregroundStyle(.primary)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            if isUser {
                Image(systemName: "person.fill")
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .padding(.bottom, 2)
            }
        }
    }

    @ViewBuilder
    private func spacerOrNil() -> some View { Spacer(minLength: 40) }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Message…", text: $draft, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .font(.body)
                .lineLimit(1...4)
                .focused($isInputFocused)
                .submitLabel(.send)
                .onSubmit(sendDraft)
                .glassEffect()

            Button(action: sendDraft) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 17, weight: .semibold))
            }
            .glassEffect()
            .buttonStyle(.borderedProminent)
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private func sendDraft() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let userMsg = ChatMessage(sender: .user, text: trimmed)
        messages.append(userMsg)
        draft = ""

        // Simulate AI response for now. Replace with real backend call.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
            let reply = ChatMessage(sender: .assistant, text: mockResponse(to: userMsg.text))
            messages.append(reply)
        }
    }

    private func mockResponse(to prompt: String) -> String {
        // Simple echo; replace with actual AI integration.
        if prompt.lowercased().contains("help") {
            return "Sure — tell me what you’re trying to achieve, and I’ll guide you step by step."
        } else if prompt.lowercased().contains("train") {
            return "To start training, provide your data source and desired goal. I’ll propose a plan."
        } else {
            return "You said: \(prompt)"
        }
    }

    private func scrollToBottom(animated: Bool) {
        // Placeholder: handled by ScrollViewReader on changes.
    }
}

#Preview {
    NavigationStack { TrainerView() }
}
