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
    
    @State private var viewModel: SignInViewModel?
    
    var body: some View {
        Group {
            if let viewModel {
                content(viewModel: viewModel)
            } else {
                ProgressView()
            }
        }
        .task {
            if viewModel == nil {
                viewModel = SignInViewModel(authService: apiClient, authManager: authManager)
            }
        }
    }
    
    private func content(viewModel: SignInViewModel) -> some View {
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
                signInSection(viewModel: viewModel)
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
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Alcanza tus objetivos, paso a paso")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
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
                    .foregroundColor(color)
            }
            .frame(width: 36)
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .frame(maxWidth: 280)
    }
    
    // MARK: - Sign In Section
    private func signInSection(viewModel: SignInViewModel) -> some View {
        VStack(spacing: 20) {
            // Mensaje de error
            if let error = viewModel.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.primary)
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
                viewModel.handleSignInResult(result)
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .disabled(viewModel.isSigningIn)
            .opacity(viewModel.isSigningIn ? 0.6 : 1.0)
            
            // Indicador de carga
            if viewModel.isSigningIn {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Autenticando...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }
            
            // Texto legal
            VStack(spacing: 4) {
                Text("Al continuar, aceptas nuestros")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 4) {
                    Button("Términos de uso") {
                        // Abrir términos
                    }
                    .font(.caption)
                    .foregroundColor(.accentColor)
                    
                    Text("y")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    Button("Política de privacidad") {
                        // Abrir privacidad
                    }
                    .font(.caption)
                    .foregroundColor(.accentColor)
                }
            }
        }
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
