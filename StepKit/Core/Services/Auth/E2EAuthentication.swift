//
//  E2EAuthentication.swift
//  StepKit
//

#if DEBUG
import Foundation

enum E2EAccountAlias: String, Codable, CaseIterable, Sendable {
    case accountA = "account-a"
    case accountB = "account-b"
}

enum E2EAuthenticationLaunchMode: Equatable, Sendable {
    case normal
    case account(E2EAccountAlias, shouldResetLocalState: Bool)
    case invalidStoredSession(shouldResetLocalState: Bool)
    case invalid
}

/// Opt-in explícito para lanzamientos de UI tests. Un argumento ausente,
/// duplicado o con un alias desconocido deja activo el flujo normal de Apple.
struct E2ELaunchConfiguration: Equatable, Sendable {
    static let accountArgument = "-StepKitE2EAccount"
    static let resetLocalStateArgument = "-StepKitE2EResetLocalState"
    static let invalidStoredSessionArgument = "-StepKitE2EInvalidStoredSession"
    static let suppressNotificationsArgument = "-StepKitE2ESuppressNotifications"

    let account: E2EAccountAlias
    let shouldResetLocalState: Bool

    init?(arguments: [String]) {
        guard case let .account(account, shouldResetLocalState) = Self
            .authenticationMode(arguments: arguments) else {
            return nil
        }

        self.account = account
        self.shouldResetLocalState = shouldResetLocalState
    }

    /// Interpreta todos los flags de autenticación como una unidad. Un reset
    /// huérfano, un flag duplicado, un alias desconocido o la mezcla de login
    /// automático y sesión inválida se clasifican como inválidos y no caen al
    /// flujo normal por accidente.
    static func authenticationMode(arguments: [String]) -> E2EAuthenticationLaunchMode {
        let accountArgumentIndices = arguments.indices.filter {
            arguments[$0] == Self.accountArgument
        }
        let invalidSessionCount = arguments.filter {
            $0 == Self.invalidStoredSessionArgument
        }.count
        let resetCount = arguments.filter {
            $0 == Self.resetLocalStateArgument
        }.count

        guard accountArgumentIndices.count <= 1,
              invalidSessionCount <= 1,
              resetCount <= 1 else {
            return .invalid
        }

        if let argumentIndex = accountArgumentIndices.first {
            guard invalidSessionCount == 0 else { return .invalid }

            let valueIndex = arguments.index(after: argumentIndex)
            guard arguments.indices.contains(valueIndex),
                  let account = E2EAccountAlias(rawValue: arguments[valueIndex]) else {
                return .invalid
            }

            return .account(account, shouldResetLocalState: resetCount == 1)
        }

        if invalidSessionCount == 1 {
            return .invalidStoredSession(shouldResetLocalState: resetCount == 1)
        }

        guard resetCount == 0 else { return .invalid }
        return .normal
    }

    /// El escenario de sesión inválida es alternativo al auto-login. Una mezcla
    /// de ambos argumentos se rechaza para que el resultado nunca sea ambiguo.
    static func requestsInvalidStoredSession(arguments: [String]) -> Bool {
        guard case .invalidStoredSession = authenticationMode(arguments: arguments) else {
            return false
        }
        return true
    }

    /// Los logins E2E y el escenario inválido conservan la supresión histórica.
    /// El flag explícito permite además relanzar una sesión persistida sin
    /// introducir un prompt del sistema en mitad del recorrido funcional.
    static func shouldSuppressNotifications(arguments: [String]) -> Bool {
        switch authenticationMode(arguments: arguments) {
        case .account, .invalidStoredSession:
            return true
        case .normal:
            return arguments.filter { $0 == suppressNotificationsArgument }.count == 1
        case .invalid:
            return false
        }
    }
}

/// Reset determinista limitado al contenedor local de StepKit: SwiftData,
/// dominio propio de UserDefaults y entradas propias de Keychain.
@MainActor
struct E2ELocalStateResetter {
    enum ResetError: Error {
        case missingPreferencesDomain
    }

    let persistence: PersistenceController
    let preferences: UserDefaults
    let preferencesDomain: String?

    init(
        persistence: PersistenceController? = nil,
        preferences: UserDefaults = .standard,
        preferencesDomain: String? = Bundle.main.bundleIdentifier
    ) {
        self.persistence = persistence ?? .shared
        self.preferences = preferences
        self.preferencesDomain = preferencesDomain
    }

    func reset(authentication: AuthManager) throws {
        guard let preferencesDomain,
              !preferencesDomain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ResetError.missingPreferencesDomain
        }

        try persistence.resetLocalDataForE2E()
        try authentication.resetAuthenticationForE2E()
        preferences.removePersistentDomain(forName: preferencesDomain)
    }
}
#endif
