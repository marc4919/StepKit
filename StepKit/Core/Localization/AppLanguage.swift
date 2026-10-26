//
//  AppLanguage.swift
//  StepKit
//
//  Idioma en el que se muestra la app: el del dispositivo, o el que la persona elija
//  para StepKit en Ajustes de iOS. De momento, español o inglés.
//

import Foundation

enum AppLanguage {
    /// «es» o «en», según la localización que iOS ha elegido para la app.
    static var code: String {
        Bundle.main.preferredLocalizations.first.flatMap { $0.hasPrefix("en") ? "en" : "es" } ?? "es"
    }

    /// Nombre del idioma para las instrucciones del modelo, que están en español.
    static var nameInSpanish: String { code == "en" ? "inglés" : "español" }

    /// Nombre del idioma en el propio idioma de la app, para mostrarlo en Perfil.
    static var displayName: String {
        Locale.current.localizedString(forLanguageCode: code)?.capitalized(with: Locale.current) ?? code
    }
}
