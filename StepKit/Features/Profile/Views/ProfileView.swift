//
//  ProfileView.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on 14/10/25.
//

import SwiftUI

struct ProfileView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var showingTermsOfService = false
    @State private var showingPrivacyPolicy = false
    @State private var showingSignOutAlert = false
    @AppStorage("globalNotificationsEnabled") private var globalNotificationsEnabled = true
    
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header del perfil
                    ProfileHeaderSection(displayName: displayName, displayTier: displayTier)

                    // Banner de suscripción
                    SubscriptionBanner()

                    // Sección de configuración
                    settingsSection
                    
                    // Sección de cuenta
                    accountSection
                    
                    Spacer(minLength: 50)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground))
            .sheet(isPresented: $showingTermsOfService) {
                TermsOfServiceView()
            }
            .sheet(isPresented: $showingPrivacyPolicy) {
                PrivacyPolicyView()
            }
            .alert("Cerrar sesión", isPresented: $showingSignOutAlert) {
                Button("Cancelar", role: .cancel) { }
                Button("Cerrar sesión", role: .destructive) {
                    signOut()
                }
            } message: {
                Text("¿Estás seguro de que quieres cerrar sesión?")
            }
        }
    }
    
    // MARK: - Settings Section
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(icon: "gearshape", title: "Configuración")

            VStack(spacing: 0) {
                // Toggle de notificaciones
                notificationsToggle

                Divider()
                    .padding(.leading, 56)

                // Términos de uso
                SettingsRow(
                    icon: "doc.text",
                    iconColor: .accentColor,
                    title: "Términos de uso",
                    showDivider: true
                ) {
                    showingTermsOfService = true
                }

                // Políticas de privacidad
                SettingsRow(
                    icon: "shield.checkered",
                    iconColor: .green,
                    title: "Políticas de privacidad",
                    showDivider: false
                ) {
                    showingPrivacyPolicy = true
                }
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Notifications Toggle
    private var notificationsToggle: some View {
        Toggle(isOn: $globalNotificationsEnabled) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.orange.opacity(0.1))
                        .frame(width: 32, height: 32)

                    Image(systemName: "bell.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.orange)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Notificaciones")
                        .font(.body)
                        .foregroundStyle(.primary)

                    Text("Recordatorios de pasos pendientes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Notificaciones. Recordatorios de pasos pendientes")
            }
        }
        .tint(.accentColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .accessibilityHint("Cuando está activado, recibirás recordatorios de pasos pendientes. Al desactivarlo, se cancelan todas las notificaciones programadas")
        .onChange(of: globalNotificationsEnabled) { _, newValue in
            if !newValue {
                // Cancelar todas las notificaciones si se desactiva
                NotificationService.shared.cancelAllNotifications()
            }
        }
    }
    
    // MARK: - Account Section
    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(icon: "person.circle", title: "Cuenta")
            
            VStack(spacing: 0) {
                // Cerrar sesión
                Button {
                    showingSignOutAlert = true
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.red.opacity(0.1))
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.red)
                        }
                        .accessibilityHidden(true)
                        
                        Text("Cerrar sesión")
                            .font(.body)
                            .foregroundStyle(.red)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel("Cerrar sesión")
                .accessibilityHint("Cierra la sesión actual y regresa a la pantalla de inicio de sesión")
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    // MARK: - Helpers
    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)

            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Derived Properties
    
    /// Nombre a mostrar en el perfil. Si no hay nombre guardado, muestra un fallback genérico.
    private var displayName: String {
        if let name = authManager.displayName,
           !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return name
        }
        return "Usuario"
    }
    
    /// Texto descriptivo del plan según el tier del usuario.
    private var displayTier: String {
        switch authManager.currentUser?.tier {
        case "premium":
            return "Versión Premium"
        case "free":
            return "Versión gratuita"
        default:
            return "Versión gratuita"
        }
    }
    
    private func signOut() {
        authManager.signOut()
        print("Cerrando sesión...")
    }
}

#Preview {
    ProfileView()
        .environment(AuthManager())
}

#Preview("Authenticated User") {
    let mockAuth = MockAuthManager(
        isAuthenticated: true,
        user: UserInfo(
            id: UUID().uuidString,
            tier: "premium",
            monthlyTokensUsed: 2500,
            monthlyTokenQuota: 10000
        ),
        token: "mock-token"
    )
    
    return ProfileView()
        .environment(mockAuth)
}

#Preview("Free Tier User") {
    let mockAuth = MockAuthManager(
        isAuthenticated: true,
        user: UserInfo(
            id: UUID().uuidString,
            tier: "free",
            monthlyTokensUsed: 500,
            monthlyTokenQuota: 1000
        ),
        token: "mock-token"
    )
    
    return ProfileView()
        .environment(mockAuth)
}




