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
    let id: UUID
    let sender: Sender
    let text: String
    let timestamp: Date
    /// La respuesta no se pudo generar; `text` es el detalle técnico.
    var isError = false
    /// Respuesta del asistente del servidor; si es false, la generó el modelo del dispositivo.
    var fromServer = false
    
    init(id: UUID = UUID(), sender: Sender, text: String, timestamp: Date = Date(), isError: Bool = false, fromServer: Bool = false) {
        self.id = id
        self.sender = sender
        self.text = text
        self.timestamp = timestamp
        self.isError = isError
        self.fromServer = fromServer
    }
}

