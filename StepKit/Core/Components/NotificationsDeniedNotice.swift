//
//  NotificationsDeniedNotice.swift
//  StepKit
//
//  Los interruptores de recordatorios guardan lo que prefieres, pero sin el permiso del
//  sistema no llega ningún aviso: se dice claramente y se ofrece el camino a Ajustes.
//

import SwiftUI
import UIKit

struct NotificationsDeniedNotice: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label {
                Text("Las notificaciones están desactivadas en Ajustes, así que estos avisos no llegarán.")
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "bell.slash.fill").foregroundStyle(.orange)
            }
            if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                Link("Abrir Ajustes", destination: url)
                    .font(.subheadline.weight(.medium))
                    .accessibilityIdentifier("reminders.openSettings")
            }
        }
    }
}

extension View {
    /// Vuelve a mirar el permiso al aparecer y al volver a la app, por si cambió en Ajustes.
    func refreshesNotificationStatus() -> some View {
        modifier(NotificationStatusRefresher())
    }
}

private struct NotificationStatusRefresher: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .task { await NotificationService.shared.checkAuthorizationStatus() }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task { await NotificationService.shared.checkAuthorizationStatus() }
            }
    }
}
