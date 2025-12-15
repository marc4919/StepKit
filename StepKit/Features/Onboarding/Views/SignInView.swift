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
    
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Spacer()
                
                // Logo y branding
                brandingSection
                
                Spacer()
                
                // Beneficios
                benefitsSection
                
                Spacer()
                
                // Sign in section
                signInSection
                    .padding(.horizontal, 24)
                    .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? 16 : 32)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(
            // Fondo con gradiente sutil
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color.accentColor.opacity(0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .sheet(isPresented: $showingTermsOfService) {
            TermsOfServiceView()
        }
        .sheet(isPresented: $showingPrivacyPolicy) {
            PrivacyPolicyView()
        }
    }
    
    // MARK: - Branding Section
    private var brandingSection: some View {
        VStack(spacing: 20) {
            // Logo animado
            ZStack {
                // Glow exterior
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.accentHighlight.opacity(0.3), Color.accentColor.opacity(0.1), .clear],
                            center: .center,
                            startRadius: 30,
                            endRadius: 80
                        )
                    )
                    .frame(width: 140, height: 140)

                // Círculo de fondo
                Circle()
                    .fill(LinearGradient.accentWithOpacity( 0.2))
                    .frame(width: 100, height: 100)

                // Icono
                Image(systemName: "target")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(LinearGradient.accentGradient)
            }
            
            // Título
            VStack(spacing: 8) {
                Text("StepKit")
                    .font(.largeTitle)
                    .bold()
                    .foregroundStyle(.primary)
                
                Text("Alcanza tus objetivos, paso a paso")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - Benefits Section
    private var benefitsSection: some View {
        VStack(spacing: 16) {
            benefitRow(
                icon: "sparkles",
                title: "Planes personalizados con IA",
                color: .purple
            )
            
            benefitRow(
                icon: "chart.line.uptrend.xyaxis",
                title: "Seguimiento de tu progreso",
                color: .green
            )
            
            benefitRow(
                icon: "bell.badge",
                title: "Recordatorios inteligentes",
                color: .orange
            )
        }
        .frame(maxWidth: .infinity)
    }
    
    private func benefitRow(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(color)
            }
            .frame(width: 36)
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .frame(maxWidth: 280)
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
            SignInWithAppleButton(.signIn) { request in
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
            errorMessage = "No hemos podido completar el inicio de sesión con Apple. Vuelve a intentarlo."
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
                    print("Error al autenticar: \(error)")
                }
            }
        }
    }
    
    private func handleLoginError(with error: Error) {
        // Errores provenientes directamente de Sign in with Apple (por ejemplo, cancelado)
        errorMessage = userFriendlyAuthErrorMessage(from: error)
        print("Could not authenticate: \(error.localizedDescription)")
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
                // Casos futuros no conocidos en tiempo de compilación
                return "Ha ocurrido un problema inesperado con Sign in with Apple. Inténtalo más tarde."
            }
        }
        
        // Errores de red típicos
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return "No se ha podido conectar con el servidor. Revisa tu conexión a internet e inténtalo de nuevo."
        }
        
        // Fallback genérico
        return "No se pudo completar la autenticación. Inténtalo de nuevo más tarde."
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
