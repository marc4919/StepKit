//
//  AppEnvironment.swift
//  StepKit
//

import Foundation

/// Configuración validada y compartida por todos los servicios de red.
struct AppEnvironment: Equatable {
    enum BuildConfiguration: String, Equatable {
        case debug
        case release
    }

    enum ConfigurationError: Error, Equatable, LocalizedError {
        case missingBaseURL
        case invalidBaseURL
        case unsupportedScheme
        case baseURLMustBeAnOrigin
        case releaseRequiresHTTPS
        case releaseRejectsLocalHost
        case releaseRejectsOverride
        case duplicateOverride
        case missingOverrideValue

        var errorDescription: String? {
            switch self {
            case .missingBaseURL:
                return "Falta la URL base de StepKit."
            case .invalidBaseURL:
                return "La URL base de StepKit no es válida."
            case .unsupportedScheme:
                return "La URL base debe usar HTTP o HTTPS."
            case .baseURLMustBeAnOrigin:
                return "La URL base debe contener únicamente esquema, host y puerto."
            case .releaseRequiresHTTPS:
                return "Release requiere una URL HTTPS."
            case .releaseRejectsLocalHost:
                return "Release no permite hosts locales."
            case .releaseRejectsOverride:
                return "Release no permite sobrescribir el destino de red."
            case .duplicateOverride:
                return "El destino de red se ha sobrescrito más de una vez."
            case .missingOverrideValue:
                return "Falta el valor del destino de red sobrescrito."
            }
        }
    }

    static let infoPlistBaseURLKey = "StepKitAPIBaseURL"

    #if DEBUG
    static let debugBaseURLLaunchArgument = "-StepKitAPIBaseURL"
    #endif

    let buildConfiguration: BuildConfiguration
    let apiBaseURL: URL

    /// Entorno de la app, resuelto una sola vez desde la configuración de build.
    static let current: AppEnvironment = {
        let configuredBaseURL = Bundle.main.object(
            forInfoDictionaryKey: infoPlistBaseURLKey
        ) as? String

        do {
            #if DEBUG
            let override = try debugBaseURLOverride(from: ProcessInfo.processInfo.arguments)
            return try configured(
                buildConfiguration: .debug,
                configuredBaseURL: configuredBaseURL,
                debugOverride: override
            )
            #else
            return try configured(
                buildConfiguration: .release,
                configuredBaseURL: configuredBaseURL
            )
            #endif
        } catch {
            preconditionFailure(
                "Configuración de red inválida: \(error.localizedDescription)"
            )
        }
    }()

    /// Construye un entorno comprobable sin depender de `Bundle` ni de argumentos de proceso.
    static func configured(
        buildConfiguration: BuildConfiguration,
        configuredBaseURL: String?,
        debugOverride: String? = nil
    ) throws -> AppEnvironment {
        if buildConfiguration == .release, debugOverride != nil {
            throw ConfigurationError.releaseRejectsOverride
        }

        guard let rawValue = debugOverride ?? configuredBaseURL,
              !rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ConfigurationError.missingBaseURL
        }

        let apiBaseURL = try validatedBaseURL(
            rawValue,
            buildConfiguration: buildConfiguration
        )

        return AppEnvironment(
            buildConfiguration: buildConfiguration,
            apiBaseURL: apiBaseURL
        )
    }

    #if DEBUG
    static func debugBaseURLOverride(from arguments: [String]) throws -> String? {
        let matchingIndices = arguments.indices.filter {
            arguments[$0] == debugBaseURLLaunchArgument
        }

        guard matchingIndices.count <= 1 else {
            throw ConfigurationError.duplicateOverride
        }

        guard let argumentIndex = matchingIndices.first else {
            return nil
        }

        let valueIndex = arguments.index(after: argumentIndex)
        guard arguments.indices.contains(valueIndex) else {
            throw ConfigurationError.missingOverrideValue
        }

        let value = arguments[valueIndex]
        guard !value.isEmpty, !value.hasPrefix("-") else {
            throw ConfigurationError.missingOverrideValue
        }

        return value
    }
    #endif

    private static func validatedBaseURL(
        _ rawValue: String,
        buildConfiguration: BuildConfiguration
    ) throws -> URL {
        let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmedValue),
              let scheme = components.scheme?.lowercased(),
              let host = components.host,
              !host.isEmpty else {
            throw ConfigurationError.invalidBaseURL
        }

        guard scheme == "http" || scheme == "https" else {
            throw ConfigurationError.unsupportedScheme
        }

        guard components.user == nil,
              components.password == nil,
              components.query == nil,
              components.fragment == nil,
              components.path.isEmpty || components.path == "/" else {
            throw ConfigurationError.baseURLMustBeAnOrigin
        }

        if buildConfiguration == .release {
            guard scheme == "https" else {
                throw ConfigurationError.releaseRequiresHTTPS
            }
            guard !isLocalHost(host) else {
                throw ConfigurationError.releaseRejectsLocalHost
            }
        }

        components.scheme = scheme
        components.path = ""

        guard let url = components.url else {
            throw ConfigurationError.invalidBaseURL
        }
        return url
    }

    private static func isLocalHost(_ rawHost: String) -> Bool {
        let host = rawHost
            .lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: "[]."))

        if host == "localhost" || host.hasSuffix(".localhost") || host.hasSuffix(".local") {
            return true
        }

        if host.contains(":"),
           (host == "::" || host == "::1" || host.hasPrefix("fe80:") ||
            host.hasPrefix("fc") || host.hasPrefix("fd")) {
            return true
        }

        let octets = host.split(separator: ".").compactMap { Int($0) }
        guard octets.count == 4, octets.allSatisfy({ (0...255).contains($0) }) else {
            return false
        }

        return octets[0] == 0 ||
            octets[0] == 10 ||
            octets[0] == 127 ||
            (octets[0] == 169 && octets[1] == 254) ||
            (octets[0] == 172 && (16...31).contains(octets[1])) ||
            (octets[0] == 192 && octets[1] == 168)
    }
}
