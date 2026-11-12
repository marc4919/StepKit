//
//  AppLog.swift
//  StepKit
//

import os

/// Registro de la app con `os.Logger`, una categoría por área.
/// Nunca se registra contenido del usuario, tokens ni datos que identifiquen a una persona.
nonisolated enum AppLog {
    private static let subsystem = "app.stepkit.StepKit"

    static let network = Logger(subsystem: subsystem, category: "network")
    static let sync = Logger(subsystem: subsystem, category: "sync")
    static let auth = Logger(subsystem: subsystem, category: "auth")
    static let store = Logger(subsystem: subsystem, category: "store")
    static let notifications = Logger(subsystem: subsystem, category: "notifications")
    static let kits = Logger(subsystem: subsystem, category: "kits")
    static let ai = Logger(subsystem: subsystem, category: "ai")
}
