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

    // MARK: - Resumen diario de pasos

    /// Cuenta cuyos Kits se avisan; sin cuenta no se programa nada.
    var ownerID: String?
    private var digestTask: Task<Void, Never>?

    /// Rehace los avisos de pasos tras un cambio (completar, editar, sincronizar…), agrupando cambios seguidos.
    func refreshStepReminders() {
        digestTask?.cancel()
        digestTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await rescheduleStepReminders()
        }
    }

    /// Un aviso al día por Kit (ver `DailyDigest`). Sustituye a los avisos por paso de versiones anteriores.
    func rescheduleStepReminders() async {
        let pending = await center.pendingNotificationRequests()
        let stale = pending.map(\.identifier).filter { $0.hasPrefix(DailyDigest.identifierPrefix) || $0.hasPrefix("step-") }
        center.removePendingNotificationRequests(withIdentifiers: stale)

        let defaults = UserDefaults.standard
        guard defaults.object(forKey: "globalNotificationsEnabled") as? Bool ?? true,
              let ownerID, !ownerID.isEmpty else { return }
        let context = PersistenceController.shared.container.mainContext
        let kits = ((try? context.fetch(FetchDescriptor<GoalEntity>(predicate: #Predicate { !$0.isDeleted }))) ?? [])
            .filter { $0.ownerID == ownerID && $0.notificationsEnabled && $0.resultConfirmedAt == nil }
        let items = DailyDigest.plan(
            kits: kits.map(DailyDigest.KitInfo.init),
            now: .now,
            hour: defaults.object(forKey: DailyDigest.hourKey) as? Int ?? 9,
            minute: defaults.object(forKey: DailyDigest.minuteKey) as? Int ?? 0,
            includesDayBefore: defaults.object(forKey: DailyDigest.dayBeforeKey) as? Bool ?? true)
        for item in items {
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = item.body
            content.sound = .default
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: item.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: item.identifier, content: content, trigger: trigger))
        }
        #if DEBUG
        print("🔔 NotificationService: \(items.count) daily reminders scheduled")
        #endif
    }

    /// Compatibilidad con las llamadas de cada pantalla: cualquier cambio rehace el resumen diario.
    func scheduleNotification(for step: StepEntity) async { await rescheduleStepReminders() }
    func scheduleNotifications(for goal: GoalEntity) async { await rescheduleStepReminders() }
    func cancelNotification(for stepId: UUID) { refreshStepReminders() }
    func cancelNotifications(for goal: GoalEntity) { refreshStepReminders() }

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
