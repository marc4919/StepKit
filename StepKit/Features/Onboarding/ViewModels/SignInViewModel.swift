//
//  SignInViewModel.swift
//  StepKit
//
//  Created by StepKit Refactoring Agent
//

import SwiftUI
import AuthenticationServices

@MainActor
@Observable
final class SignInViewModel {
    var isSigningIn = false
    var errorMessage: String?
    
    private let authService: AuthServiceProtocol
    private let authManager: AuthManager
    
    init(authService: AuthServiceProtocol, authManager: AuthManager) {
        self.authService = authService
        self.authManager = authManager
    }
    
    func handleSignInResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            handleSuccessfulLogin(with: authorization)
        case .failure(let error):
            handleLoginError(with: error)
        }
    }
    
    private func handleSuccessfulLogin(with authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityTokenData = appleIDCredential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8) else {
            errorMessage = "No hemos podido completar el inicio de sesión con Apple. Vuelve a intentarlo."
            return
        }
        
        // Obtener nombre
        let displayNameFromApple: String = {
            if let fullName = appleIDCredential.fullName {
                let components = [fullName.givenName, fullName.familyName]
                    .compactMap { $0 }
                    .joined(separator: " ")
                if !components.trimmingCharacters(in: .whitespaces).isEmpty {
                    return components
                }
            }
            if let email = appleIDCredential.email,
               !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return email
            }
            return ""
        }()
        
        isSigningIn = true
        errorMessage = nil
        
        Task {
            do {
                let response = try await authService.signInWithApple(identityToken: identityToken)
                
                authManager.saveAuth(token: response.token, user: response.user)
                
                if !displayNameFromApple.isEmpty {
                    authManager.updateDisplayName(displayNameFromApple)
                }
                
                isSigningIn = false
            } catch {
                isSigningIn = false
                errorMessage = userFriendlyAuthErrorMessage(from: error)
                print("Error al autenticar: \(error)")
            }
        }
    }
    
    private func handleLoginError(with error: Error) {
        errorMessage = userFriendlyAuthErrorMessage(from: error)
        print("Could not authenticate: \(error.localizedDescription)")
    }
    
    private func userFriendlyAuthErrorMessage(from error: Error) -> String {
        // Errores de tu API
        if let apiError = error as? APIError, let description = apiError.errorDescription {
            return description
        }
        
        // Errores de Sign in with Apple
        if let authError = error as? ASAuthorizationError {
            switch authError.code {
            case .canceled:
                return "Has cancelado el inicio de sesión."
            case .failed:
                return "No se pudo completar el inicio de sesión con Apple. Inténtalo de nuevo."
            case .invalidResponse:
                return "La respuesta de Apple no ha sido válida. Vuelve a intentarlo en unos minutos."
            case .notHandled:
                return "La solicitud de inicio de sesión no se ha podido procesar. Inténtalo de nuevo."
            case .notInteractive:
                return "La solicitud de inicio de sesión requiere interacción del usuario."
            case .matchedExcludedCredential:
                return "La credencial está excluida. Inténtalo de nuevo."
            case .credentialImport:
                return "Error al importar la credencial. Inténtalo de nuevo."
            case .credentialExport:
                return "Error al exportar la credencial. Inténtalo de nuevo."
            case .preferSignInWithApple:
                return "Se prefiere usar Sign in with Apple. Inténtalo de nuevo."
            case .deviceNotConfiguredForPasskeyCreation:
                return "El dispositivo no está configurado para crear passkeys. Verifica la configuración."
            case .unknown:
                return "Ha ocurrido un problema inesperado con Sign in with Apple. Inténtalo más tarde."
            @unknown default:
                return "Ha ocurrido un problema inesperado con Sign in with Apple. Inténtalo más tarde."
            }
        }
        
        // Errores de red típicos
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return "No se ha podido conectar con el servidor. Revisa tu conexión a internet e inténtalo de nuevo."
        }
        
        return "No se pudo completar la autenticación. Inténtalo de nuevo más tarde."
    }
}
