//
//  AccountDeletionService.swift
//  StepKit
//

import AuthenticationServices
import Foundation
import UIKit

/// Borra la cuenta desde la app (App Review 5.1.1(v)). Antes pide a la persona que confirme
/// con Apple: el servidor comprueba que es la misma cuenta y revoca sus tokens de Sign in with
/// Apple con el authorization code recién emitido (TN3194). Después se limpia todo lo local.
@MainActor
enum AccountDeletionService {
    enum Failure: Error {
        case cancelled
        case appleFailed
        case server(Int)
    }

    struct AppleConfirmation {
        let identityToken: String
        let authorizationCode: String
    }

    static func deleteAccount(
        token: String,
        apiClient: any APIClientProtocol,
        authentication: AuthManager,
        syncManager: SyncManager?
    ) async throws {
        let confirmation = try await AppleReauthentication().confirm()

        // Ningún sync en vuelo debe volver a subir datos mientras se borra la cuenta.
        if let syncManager {
            syncManager.stopAutoSync()
            await syncManager.cancelAndWaitForSync()
        }

        var request = apiClient.authenticatedRequest(path: "/me", method: "DELETE", token: token)
        request.httpBody = try JSONEncoder().encode([
            "identityToken": confirmation.identityToken,
            "authorizationCode": confirmation.authorizationCode,
        ])
        request.timeoutInterval = 30
        let (_, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        // 401: la cuenta ya no existe en el servidor; se termina igualmente la limpieza local.
        guard (200...299).contains(status) || status == 401 else {
            syncManager?.startAutoSync()
            throw Failure.server(status)
        }

        clearLocalState(authentication: authentication)
    }

    /// Deja el dispositivo como recién instalado: datos, conversaciones, avisos, preferencias y sesión.
    static func clearLocalState(authentication: AuthManager) {
        try? PersistenceController.shared.deleteAllLocalData()
        KitAssistantStore.shared.removeAll()
        NotificationService.shared.cancelAllNotifications()
        if let domain = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: domain)
        }
        authentication.signOut()
        // La bienvenida se observa con @AppStorage: se fija explícitamente tras limpiar el dominio.
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
    }
}

/// Pide a Apple una autorización nueva sin datos extra (ni nombre ni correo).
@MainActor
private final class AppleReauthentication: NSObject, ASAuthorizationControllerDelegate,
                                           ASAuthorizationControllerPresentationContextProviding {
    private var continuation: CheckedContinuation<AccountDeletionService.AppleConfirmation, Error>?

    func confirm() async throws -> AccountDeletionService.AppleConfirmation {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = []
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let key = scenes.flatMap(\.windows).first(where: \.isKeyWindow) { return key }
        // Sin ventana activa se ancla a la escena: Apple pide una ventana para mostrar su confirmación.
        guard let scene = scenes.first else { preconditionFailure("No hay escena para mostrar Sign in with Apple") }
        return ASPresentationAnchor(windowScene: scene)
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityToken = credential.identityToken.flatMap({ String(data: $0, encoding: .utf8) }),
              let code = credential.authorizationCode.flatMap({ String(data: $0, encoding: .utf8) }) else {
            finish(.failure(AccountDeletionService.Failure.appleFailed))
            return
        }
        finish(.success(.init(identityToken: identityToken, authorizationCode: code)))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        let cancelled = (error as? ASAuthorizationError)?.code == .canceled
        finish(.failure(cancelled ? AccountDeletionService.Failure.cancelled : AccountDeletionService.Failure.appleFailed))
    }

    private func finish(_ result: Result<AccountDeletionService.AppleConfirmation, Error>) {
        continuation?.resume(with: result)
        continuation = nil
    }
}
