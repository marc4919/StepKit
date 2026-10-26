//
//  NotificationService.swift
//  StepKit
//
//  Servicio para manejar notificaciones locales de recordatorio
//

import Foundation
import UserNotifications
import SwiftData

@MainActor
@Observable
final class NotificationService {

    // MARK: - Singleton

    static let shared = NotificationService()

    // MARK: - Properties

    private let center = UNUserNotificationCenter.current()

    /// Estado de autorización de notificaciones
    private(set) var isAuthorized: Bool = false

    /// Los recorridos E2E no deben mostrar el diálogo del sistema.
    var promptsSuppressed = false

    /// Pide permiso solo si aún no se ha preguntado; para usar en el momento en que
    /// el usuario espera un aviso (guardar su primer Kit, reservar una sesión).
    func requestAuthorizationIfNeeded() async {
        guard !promptsSuppressed else { return }
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            await requestAuthorization()
        } else {
            isAuthorized = settings.authorizationStatus == .authorized
        }
    }

    // MARK: - Authorization

    /// Solicita permisos de notificación al usuario
    /// - Returns: true si el usuario concedió permisos
    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
            return granted
        } catch {
            #if DEBUG
            print(
                "❌ NotificationService: authorization failed, " +
                "errorType=\(String(describing: type(of: error)))"
            )
            #endif
            return false
        }
    }

    /// Verifica el estado actual de autorización
    func checkAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }

    // MARK: - Schedule Notifications

    /// Programa una notificación para un paso específico
    /// La notificación se enviará 1 día antes del suggestedDeadline a las 9:00 AM
    func scheduleNotification(for step: StepEntity) async {
        // Validar condiciones
        guard let deadline = step.suggestedDeadline,
              step.notificationEnabled,
              step.goal?.notificationsEnabled ?? true,
              !step.isCompleted else {
            return
        }

        // Calcular fecha de notificación (1 día antes)
        let calendar = Calendar.current
        guard let notificationDate = calendar.date(byAdding: .day, value: -1, to: deadline),
              notificationDate > Date() else {
            // Si la fecha ya pasó o es hoy, no programar
            return
        }

        // Configurar componentes de fecha para las 9:00 AM
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: notificationDate)
        dateComponents.hour = 9
        dateComponents.minute = 0

        // Crear contenido de la notificación
        let content = UNMutableNotificationContent()
        content.title = step.goal?.planTitle ?? String(localized: "Recordatorio")
        content.body = String(localized: "Mañana: \(step.stepTitle)")
        content.sound = .default

        // Crear trigger basado en fecha
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

        // Crear request con identificador único
        let identifier = notificationIdentifier(for: step.id)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        // Programar notificación
        do {
            try await center.add(request)
            #if DEBUG
            print("✅ NotificationService: scheduled step=\(step.id)")
            #endif
        } catch {
            #if DEBUG
            print(
                "❌ NotificationService: scheduling failed, " +
                "errorType=\(String(describing: type(of: error)))"
            )
            #endif
        }
    }

    /// Programa notificaciones para todos los pasos de un kit
    func scheduleNotifications(for goal: GoalEntity) async {
        guard goal.notificationsEnabled else { return }

        for step in goal.steps where !step.isCompleted {
            await scheduleNotification(for: step)
        }
    }

    // MARK: - Cancel Notifications

    /// Cancela la notificación de un paso específico
    func cancelNotification(for stepId: UUID) {
        let identifier = notificationIdentifier(for: stepId)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        #if DEBUG
        print("🔕 NotificationService: Notificación cancelada para step \(stepId)")
        #endif
    }

    /// Cancela todas las notificaciones de un kit
    func cancelNotifications(for goal: GoalEntity) {
        let identifiers = goal.steps.map { notificationIdentifier(for: $0.id) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)

        #if DEBUG
        print("🔕 NotificationService: cancelled count=\(identifiers.count)")
        #endif
    }

    /// Cancela todas las notificaciones pendientes
    func cancelAllNotifications() {
        center.removeAllPendingNotificationRequests()

        #if DEBUG
        print("🔕 NotificationService: Todas las notificaciones canceladas")
        #endif
    }

    // MARK: - Sesiones reservadas

    /// Recordatorio 10 minutos antes de una sesión futura. Reprogramar con el mismo
    /// identificador sustituye el anterior, así que es idempotente.
    func scheduleReminder(for session: WorkSessionEntity, kitTitle: String, stepTitle: String?) async {
        let identifier = sessionIdentifier(for: session.id)
        guard session.reminderEnabled, session.deletedAt == nil else {
            center.removePendingNotificationRequests(withIdentifiers: [identifier])
            return
        }
        let fireDate = session.startsAt.addingTimeInterval(-10 * 60)
        guard fireDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = kitTitle
        content.body = String(localized: "En 10 min: \(stepTitle ?? String(localized: "tu sesión")) · \(session.durationMinutes) min")
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        do {
            try await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
        } catch {
            #if DEBUG
            print("❌ NotificationService: session reminder failed, errorType=\(String(describing: type(of: error)))")
            #endif
        }
    }

    func cancelReminder(forSession id: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [sessionIdentifier(for: id)])
    }

    private func sessionIdentifier(for sessionId: UUID) -> String {
        "session-\(sessionId.uuidString)"
    }

    // MARK: - Helpers

    /// Genera un identificador único para la notificación de un paso
    private func notificationIdentifier(for stepId: UUID) -> String {
        "step-\(stepId.uuidString)"
    }

    /// Obtiene las notificaciones pendientes (para debug)
    func getPendingNotifications() async -> [UNNotificationRequest] {
        await center.pendingNotificationRequests()
    }
}

// MARK: - Singleton Extension

extension NotificationService {
    /// Acceso conveniente al singleton
    static var current: NotificationService { shared }
}
