//
//  TrainerViewModel.swift
//  StepKit
//

import SwiftUI

/// Estado del chat de una conversación del asistente del Kit.
/// Lo rellena el asistente del servidor (`KitAssistRemote`) y lo pinta `AssistantHomeView`.
@Observable
@MainActor
final class TrainerViewModel {
    var messages: [ChatMessage] = []
    var draft: String = ""
    var isTyping: Bool = false
    var isResponding: Bool = false
}
