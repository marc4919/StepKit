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
            Eres el asistente de StepKit, una app de productividad que ayuda a las personas
            a alcanzar sus objetivos dividiéndolos en pasos accionables.

            Tu personalidad:
            - Eres amable, motivador y práctico
            - Celebras los logros del usuario
            - Ofreces consejos específicos basados en sus datos
            - Mantienes un tono positivo pero realista

            CONTEXTO ACTUAL DEL USUARIO:
            \(contextString)

            \(quickActionContext)

            REGLAS:
            - Responde siempre en \(AppLanguage.nameInSpanish)
            - Sé conciso: 2-4 oraciones normalmente, máximo un párrafo corto
            - Usa los datos del usuario para personalizar cada respuesta
            - No inventes datos que no tengas
            - Si el usuario no tiene kits, anímalo a crear uno
            - Usa emojis con moderación (máximo 1-2 por respuesta)
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
                    let stream = currentSession.streamResponse(to: message)

                    var lastContent = ""
                    for try await partialResponse in stream {
                        let currentContent = partialResponse.content

                        // Foundation Models devuelve contenido acumulado
                        // Emitimos el contenido completo cada vez (la UI lo reemplazará)
                        if currentContent != lastContent {
                            continuation.yield(currentContent)
                            lastContent = currentContent
                        }
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
            let response = try await session.respond(to: message)
            return response.content
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
