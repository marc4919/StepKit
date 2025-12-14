//
//  APIClientProtocol.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on [Date]
//

import Foundation

/// Protocolo para el cliente de API, permite mocking en tests y previews
protocol APIClientProtocol: AuthServiceProtocol {
    /// Autentica con Apple Sign In enviando el identity token al backend
    /// - Parameter identityToken: El token de identidad de Apple
    /// - Returns: Respuesta con JWT y información del usuario
    func signInWithApple(identityToken: String) async throws -> AuthResponse
    
    /// Genera un kit usando IA a partir de la descripción del objetivo
    /// - Parameters:
    ///   - request: Datos del objetivo a generar
    ///   - token: Token JWT de autenticación
    /// - Returns: Respuesta con el kit generado y uso de tokens
    func generateKit(from request: AIGenerateKitRequest, token: String) async throws -> AIGenerateKitResponse
    
    /// Crea un URLRequest autenticado con el JWT en el header
    /// - Parameters:
    ///   - path: Ruta del endpoint (ej: "/sync/batch")
    ///   - method: Método HTTP (GET, POST, etc.)
    ///   - token: Token JWT de autenticación
    /// - Returns: URLRequest configurado con el token de autenticación
    func authenticatedRequest(path: String, method: String, token: String) -> URLRequest
    
    /// Genera un kit usando IA con streaming SSE
    /// Emite eventos: kit_info -> step (x N) -> done
    /// - Parameters:
    ///   - request: Datos del objetivo a generar
    ///   - token: Token JWT de autenticación
    /// - Returns: Stream de eventos de creación del kit
    func streamKitGeneration(from request: AIGenerateKitRequest, token: String) -> AsyncThrowingStream<AIChatStreamEvent, Error>
    func verifySubscription(transactionId: String, token: String) async throws -> VerifySubscriptionResponse
}

