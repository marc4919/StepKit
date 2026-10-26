//
//  SignInView.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on 9/10/25.
//

import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AuthManager.self) private var authManager
    @Environment(\.apiClient) private var apiClient
    @State private var isSigningIn = false
    @State private var errorMessage: String?
    @State private var showingTermsOfService = false
    @State private var showingPrivacyPolicy = false
    
    
    @State private var size = CGSize(width: 400, height: 800)
    /// Apaisado o pantalla exterior del iPhone Duo: marca a un lado y acceso al otro.
    private var wide: Bool { size.width > size.height }
    /// Pantalla grande en vertical (iPhone Duo abierto, iPad).
    private var roomy: Bool { size.width >= 600 }

    var body: some View {
        Group {
            if wide {
                HStack(spacing: 24) {
                    brandingSection.frame(maxWidth: .infinity)
                    ScrollView {
                        // Centrado en vertical: con el iPhone Duo abierto no se queda arriba.
                        VStack(spacing: 16) {
                            benefitsSection
                            signInSection.frame(maxWidth: 440)
                        }
                        .padding(.vertical)
                        .frame(maxWidth: .infinity, minHeight: size.height)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal)
            } else {
                ScrollView {
                    VStack(spacing: 18) {
                        Spacer(minLength: 12)
                        brandingSection
                        benefitsSection.padding(.horizontal, 24)
                        // En pantallas grandes, todo en un bloque centrado; en iPhone, el botón abajo, al alcance del pulgar.
                        if !roomy { Spacer(minLength: 12) }
                        signInSection.padding(.horizontal, 24).frame(maxWidth: 480)
                        if roomy { Spacer(minLength: 12) }
                    }
                    .padding(.vertical, 12)
                    .frame(minHeight: size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .background { EntryBackground() }
        .sheet(isPresented: $showingTermsOfService) {
            TermsOfServiceView()
        }
        .sheet(isPresented: $showingPrivacyPolicy) {
            PrivacyPolicyView()
        }
    }

    // MARK: - Branding Section
    private var brandingSection: some View {
        VStack(spacing: 8) {
            OrbitMark(height: wide ? min(size.height * 0.5, 220) : 190, animated: true)
                .padding(.horizontal, 40)
            Text("StepKit")
                .font(.largeTitle.bold())
                .accessibilityAddTraits(.isHeader)
            Text("Un paso claro para volver")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Benefits Section
    /// Bloque de ventajas con su ancho natural, centrado y algo separado del lema.
    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            WelcomeFeatureRow(symbol: Symbols.kits, color: .accentColor, text: String(localized: "Organiza tus objetivos"))
            WelcomeFeatureRow(symbol: "chart.line.uptrend.xyaxis", color: .green, text: String(localized: "Avanza paso a paso"))
            WelcomeFeatureRow(symbol: "bell.fill", color: .purple, text: String(localized: "Recupera el hilo cuando vuelvas"))
        }
        .fixedSize(horizontal: true, vertical: false)
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
    }

    // MARK: - Sign In Section
    private var signInSection: some View {
        VStack(spacing: 20) {
            // Mensaje de error
            if let error = errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
            }
            
            // Botón de Apple
            SignInWithAppleButton(.continue) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                switch result {
                case .success(let authorization):
                    handleSuccessfulLogin(with: authorization)
                case .failure(let error):
                    handleLoginError(with: error)
                }
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .disabled(isSigningIn)
            .opacity(isSigningIn ? 0.6 : 1.0)
            .accessibilityIdentifier("auth.signInWithApple")
            
            // Indicador de carga
            if isSigningIn {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Autenticando...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }
            
            // Texto legal
            VStack(spacing: 4) {
                Text("Al continuar, aceptas nuestros")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 4) {
                    Button("Términos de uso") {
                        showingTermsOfService = true
                    }
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
                    .accessibilityAddTraits(.isButton)
                    
                    Text("y")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Política de privacidad") {
                        showingPrivacyPolicy = true
                    }
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
                    .accessibilityAddTraits(.isButton)
                }
            }
        }
    }
    
    // MARK: - Auth Handlers
    private func handleSuccessfulLogin(with authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityTokenData = appleIDCredential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8) else {
            // Mensaje más humano cuando falla la obtención del token
            errorMessage = String(localized: "No hemos podido completar el inicio de sesión con Apple. Vuelve a intentarlo.")
            return
        }
        
        // Intentar construir un nombre de usuario amigable a partir de los datos de Apple
        let displayNameFromApple: String = {
            if let fullName = appleIDCredential.fullName {
                let components = [fullName.givenName, fullName.familyName]
                    .compactMap { $0 }
                    .joined(separator: " ")
                if !components.trimmingCharacters(in: .whitespaces).isEmpty {
                    return components
                }
            }
            // Fallback: usar el email la primera vez que Apple lo proporciona
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
                let response = try await apiClient.signInWithApple(identityToken: identityToken)
                
                await MainActor.run {
                    authManager.saveAuth(token: response.token, user: response.user)
                    
                    if !displayNameFromApple.isEmpty {
                        authManager.updateDisplayName(displayNameFromApple)
                    }
                    
                    isSigningIn = false
                    // La navegación se manejará automáticamente por el estado de isAuthenticated en StepKitApp
                }
            } catch {
                await MainActor.run {
                    isSigningIn = false
                    // Mostrar mensaje amigable según el tipo de error
                    errorMessage = userFriendlyAuthErrorMessage(from: error)
                    #if DEBUG
                    print("Authentication failed: type=\(String(describing: type(of: error)))")
                    #endif
                }
            }
        }
    }
    
    private func handleLoginError(with error: Error) {
        // Errores provenientes directamente de Sign in with Apple (por ejemplo, cancelado)
        errorMessage = userFriendlyAuthErrorMessage(from: error)
        #if DEBUG
        print("Apple authorization failed: type=\(String(describing: type(of: error)))")
        #endif
    }
    
    // MARK: - Error Mapping
    
    /// Convierte errores técnicos (Apple, red, backend) en mensajes claros para el usuario.
    private func userFriendlyAuthErrorMessage(from error: Error) -> String {
        // Errores de tu API
        if let apiError = error as? APIError, let description = apiError.errorDescription {
            return description
        }
        
        // Errores de Sign in with Apple
        if let authError = error as? ASAuthorizationError {
            switch authError.code {
            case .canceled:
                return String(localized: "Has cancelado el inicio de sesión.")
            case .failed:
                return String(localized: "No se pudo completar el inicio de sesión con Apple. Inténtalo de nuevo.")
            case .invalidResponse:
                return String(localized: "La respuesta de Apple no ha sido válida. Vuelve a intentarlo en unos minutos.")
            case .notHandled:
                return String(localized: "La solicitud de inicio de sesión no se ha podido procesar. Inténtalo de nuevo.")
            case .notInteractive:
                return String(localized: "La solicitud de inicio de sesión requiere interacción del usuario.")
            case .matchedExcludedCredential:
                return String(localized: "La credencial está excluida. Inténtalo de nuevo.")
            case .credentialImport:
                return String(localized: "Error al importar la credencial. Inténtalo de nuevo.")
            case .credentialExport:
                return String(localized: "Error al exportar la credencial. Inténtalo de nuevo.")
            case .preferSignInWithApple:
                return String(localized: "Se prefiere usar Sign in with Apple. Inténtalo de nuevo.")
            case .deviceNotConfiguredForPasskeyCreation:
                return String(localized: "El dispositivo no está configurado para crear passkeys. Verifica la configuración.")
            case .unknown:
                return String(localized: "Ha ocurrido un problema inesperado con Sign in with Apple. Inténtalo más tarde.")
            @unknown default:
                // Casos futuros no conocidos en tiempo de compilación
                return String(localized: "Ha ocurrido un problema inesperado con Sign in with Apple. Inténtalo más tarde.")
            }
        }
        
        // Errores de red típicos
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return String(localized: "No se ha podido conectar con el servidor. Revisa tu conexión a internet e inténtalo de nuevo.")
        }
        
        // Fallback genérico
        return String(localized: "No se pudo completar la autenticación. Inténtalo de nuevo más tarde.")
    }
}

#Preview {
    SignInView()
        .environment(AuthManager())
        .environment(\.apiClient, APIClient())
}

#Preview("Dark Mode") {
    SignInView()
        .preferredColorScheme(.dark)
        .environment(AuthManager())
        .environment(\.apiClient, APIClient())
}

#if DEBUG
#Preview("Mock - Login Success") {
    let mockAPI = MockAPIClient()
    mockAPI.shouldFailLogin = false
    mockAPI.simulatedDelay = 0.1
    
    return SignInView()
        .environment(AuthManager())
        .environment(\.apiClient, mockAPI)
}

#Preview("Mock - Login Error") {
    let mockAPI = MockAPIClient()
    mockAPI.shouldFailLogin = true
    mockAPI.simulatedDelay = 0.1
    
    return SignInView()
        .environment(AuthManager())
        .environment(\.apiClient, mockAPI)
}
#endif
