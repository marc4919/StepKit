//
//  AssistantService.swift
//  StepKit
//
//  Servicio que maneja la conversación con el Foundation Model on-device
//

import Foundation
import FoundationModels

// MARK: - Assistant Service

/// Servicio actor que encapsula la lógica del asistente con Foundation Model
@MainActor
@Observable
final class AssistantService {

    // MARK: - Properties

    /// Sesión actual del modelo (mantiene contexto de conversación)
    private var session: LanguageModelSession?

    /// Referencia al modelo del sistema
    private let model = SystemLanguageModel.default

    /// Indica si el modelo está disponible
    var isAvailable: Bool {
        model.availability == .available
    }

    /// Razón de indisponibilidad (si aplica)
    var unavailabilityReason: String? {
        switch model.availability {
        case .available:
            return nil
        case .unavailable(.deviceNotEligible):
            return String(localized: "Este dispositivo no es compatible con Apple Intelligence")
        case .unavailable(.appleIntelligenceNotEnabled):
            return String(localized: "Activa Apple Intelligence en Ajustes para usar el asistente")
        case .unavailable(.modelNotReady):
            return String(localized: "El modelo aún no está listo. Inténtalo de nuevo más tarde")
        case .unavailable:
            return String(localized: "El asistente no está disponible en este momento")
        @unknown default:
            return String(localized: "El asistente no está disponible")
        }
    }

    /// Contador de mensajes en la sesión actual (para control de contexto)
    private var messageCount = 0

    /// Límite de mensajes antes de resetear (para evitar exceder contexto)
    private let maxMessagesPerSession = 20

    // MARK: - Instructions

    /// Instrucciones base del sistema para el asistente
    private func buildInstructions(context: AssistantContext, quickAction: QuickActionType?) -> Instructions {
        let contextString = context.toPromptString()
        let quickActionContext = quickAction?.additionalPromptContext(for: context) ?? ""

        return Instructions {
            """
            Eres el asistente de StepKit, una app que ayuda a alcanzar objetivos con planes de pasos.
            Cada objetivo es un Kit; un Kit tiene pasos con fecha. El título del Kit es el objetivo, no un paso.

            Tono: cercano, práctico y realista. Celebra solo lo que ya está hecho: si no hay pasos
            completados, no felicites; ayuda a empezar por el próximo paso.

            CONTEXTO ACTUAL DEL USUARIO:
            \(contextString)

            \(quickActionContext)

            REGLAS:
            - Responde siempre en \(AppLanguage.nameInSpanish)
            - Responde a lo que te dicen. A un saludo, saluda y ofrece ayuda concreta con el próximo paso.
            - Sé conciso: 2-4 frases, sin listas largas
            - Usa solo los datos del contexto; no inventes pasos, fechas ni avances
            - Nombra los pasos por su título exacto
            - Sin emojis y sin signos repetidos (nada de «!!!» ni «¡¡¡»)
            - Si el usuario no tiene Kits, anímalo a crear uno
            """
        }
    }

    // MARK: - Public Methods

    /// Envía un mensaje al asistente y obtiene una respuesta con streaming
    /// - Parameters:
    ///   - message: Mensaje del usuario
    ///   - context: Contexto actual del usuario (kits, progreso, etc.)
    ///   - quickAction: Tipo de acción rápida (opcional)
    /// - Returns: Stream asíncrono de texto (contenido acumulado)
    func chat(
        message: String,
        context: AssistantContext,
        quickAction: QuickActionType? = nil
    ) async throws -> AsyncThrowingStream<String, Error> {
        guard isAvailable else {
            throw AssistantError.modelUnavailable(unavailabilityReason ?? String(localized: "Modelo no disponible"))
        }

        // Crear nueva sesión si es necesario o si se excedió el límite
        if session == nil || messageCount >= maxMessagesPerSession {
            await resetConversation(with: context, quickAction: quickAction)
        }

        guard let currentSession = session else {
            throw AssistantError.sessionCreationFailed
        }

        messageCount += 1

        // Crear stream de respuesta
        // Foundation Models devuelve contenido acumulado, no deltas
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    // Usar streamResponse para obtener texto en tiempo real
                    // El modelo del dispositivo puede entrar en bucle («¡¡¡¡…»): temperatura baja y un tope de longitud.
                    let options = GenerationOptions(temperature: 0.4, maximumResponseTokens: 300)
                    let stream = currentSession.streamResponse(to: message, options: options)

                    var lastContent = ""
                    for try await partialResponse in stream {
                        var currentContent = partialResponse.content
                        // Si empieza a repetir, se corta ahí y no se sigue generando.
                        let looping = RepetitionGuard.cut(currentContent)
                        if let looping { currentContent = looping }

                        // Foundation Models devuelve contenido acumulado
                        // Emitimos el contenido completo cada vez (la UI lo reemplazará)
                        if currentContent != lastContent {
                            continuation.yield(currentContent)
                            lastContent = currentContent
                        }
                        if looping != nil { break }
                    }

                    continuation.finish()
                } catch let error as LanguageModelSession.GenerationError {
                    continuation.finish(throwing: AssistantError.from(generationError: error))
                } catch {
                    continuation.finish(throwing: AssistantError.unknown(error.localizedDescription))
                }
            }
        }
    }

    /// Envía un mensaje y obtiene la respuesta completa (sin streaming)
    /// - Parameters:
    ///   - message: Mensaje del usuario
    ///   - context: Contexto actual del usuario
    ///   - quickAction: Tipo de acción rápida (opcional)
    /// - Returns: Respuesta completa del asistente
    func respond(
        message: String,
        context: AssistantContext,
        quickAction: QuickActionType? = nil
    ) async throws -> String {
        guard isAvailable else {
            throw AssistantError.modelUnavailable(unavailabilityReason ?? String(localized: "Modelo no disponible"))
        }

        // Crear nueva sesión si es necesario
        if session == nil || messageCount >= maxMessagesPerSession {
            await resetConversation(with: context, quickAction: quickAction)
        }

        guard let session = session else {
            throw AssistantError.sessionCreationFailed
        }

        messageCount += 1

        do {
            let response = try await session.respond(to: message,
                                                     options: GenerationOptions(temperature: 0.4, maximumResponseTokens: 300))
            return RepetitionGuard.cut(response.content) ?? response.content
        } catch let error as LanguageModelSession.GenerationError {
            throw AssistantError.from(generationError: error)
        } catch {
            throw AssistantError.unknown(error.localizedDescription)
        }
    }

    /// Reinicia la conversación (crea nueva sesión)
    /// - Parameters:
    ///   - context: Nuevo contexto del usuario
    ///   - quickAction: Tipo de acción rápida para las instrucciones
    func resetConversation(with context: AssistantContext? = nil, quickAction: QuickActionType? = nil) async {
        let ctx = context ?? .empty
        let instructions = buildInstructions(context: ctx, quickAction: quickAction)
        session = LanguageModelSession(instructions: instructions)
        messageCount = 0

        #if DEBUG
        print("")
        print("╔════════════════════════════════════════════════════════════════╗")
        print("║  🤖 ASSISTANT SERVICE - Nueva sesión creada                     ║")
        print("╠════════════════════════════════════════════════════════════════╣")
        print("║  📊 Kits en contexto: \(ctx.kits.count)")
        print("║  🎯 Quick action: \(quickAction?.rawValue ?? "ninguna")")
        print("╚════════════════════════════════════════════════════════════════╝")
        print("")
        #endif
    }

    /// Actualiza el contexto de la sesión actual
    /// Útil cuando cambian los datos del usuario durante la conversación
    func updateContext(_ context: AssistantContext, quickAction: QuickActionType? = nil) async {
        await resetConversation(with: context, quickAction: quickAction)
    }
}

// MARK: - Repetition Guard

/// Detecta cuando el modelo del dispositivo degenera repitiendo lo mismo y devuelve el texto bueno.
enum RepetitionGuard {
    /// Texto hasta antes de la repetición, o nil si la respuesta está bien.
    static func cut(_ text: String) -> String? {
        let chars = Array(text)
        var runStart = 0
        for i in chars.indices where i > 0 {
            if chars[i] != chars[i - 1] { runStart = i; continue }
            let run = i - runStart + 1
            // «¡¡¡¡», «!!!!», «....»: 4 signos iguales; letras o espacios: 8.
            let limit = chars[i].isLetter || chars[i].isNumber || chars[i].isWhitespace ? 8 : 4
            if run >= limit { return clean(String(chars[..<runStart])) }
        }
        // La misma frase corta repetida tres veces seguidas.
        for length in 6...40 where chars.count >= length * 3 {
            let tail = chars.suffix(length * 3)
            let a = tail.prefix(length), b = tail.dropFirst(length).prefix(length), c = tail.suffix(length)
            if Array(a) == Array(b), Array(b) == Array(c) {
                return clean(String(chars.dropLast(length * 2)))
            }
        }
        return nil
    }

    private static func clean(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        while let last = result.last, ",;:¡¿-–".contains(last) { result.removeLast() }
        if let last = result.last, !".!?…".contains(last) { result += "." }
        return result
    }
}

// MARK: - Assistant Errors

/// Errores específicos del servicio de asistente
enum AssistantError: LocalizedError {
    case modelUnavailable(String)
    case sessionCreationFailed
    case contextWindowExceeded
    case guardrailViolation
    case cancelled
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .modelUnavailable(let reason):
            return reason
        case .sessionCreationFailed:
            return String(localized: "No se pudo iniciar la conversación")
        case .contextWindowExceeded:
            return String(localized: "La conversación es muy larga. Se ha reiniciado.")
        case .guardrailViolation:
            return String(localized: "No puedo responder a eso. ¿Hay algo más en lo que pueda ayudarte?")
        case .cancelled:
            return String(localized: "La solicitud fue cancelada")
        case .unknown(let message):
            return message
        }
    }

    /// Convierte errores del modelo a errores del asistente
    static func from(generationError: LanguageModelSession.GenerationError) -> AssistantError {
        switch generationError {
        case .exceededContextWindowSize:
            return .contextWindowExceeded
        case .guardrailViolation:
            return .guardrailViolation
        default:
            return .unknown(generationError.localizedDescription)
        }
    }
}

// MARK: - Singleton

extension AssistantService {
    /// Instancia compartida del servicio
    static let shared = AssistantService()
}
