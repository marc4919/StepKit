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
    
    // Colores del tema (consistente con otras vistas)
    private let accentBlue = Color(red: 0.0, green: 0.48, blue: 1.0)
    private let accentHighlight = Color(red: 0.55, green: 0.82, blue: 1.0)
    private let glowColor = Color(red: 0.2, green: 0.6, blue: 1.0)
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header del perfil
                    profileHeaderSection
                    
                    // Banner de suscripción
                    subscriptionBanner
                    
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
    
    // MARK: - Profile Header
    private var profileHeaderSection: some View {
        VStack(spacing: 12) {
            // Avatar del usuario
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [accentHighlight.opacity(0.3), accentBlue.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: glowColor.opacity(0.3), radius: 12, x: 0, y: 4)
                
                Image(systemName: "person.fill")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [accentHighlight, accentBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 4) {
                Text(displayName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(displayTier)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 16)
    }
    
    // MARK: - Subscription Banner
    private var subscriptionBanner: some View {
        NavigationLink(destination: SubscriptionView()) {
            HStack(spacing: 14) {
                // Icono
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "crown.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.yellow)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Desbloquea StepKit Pro")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text("Accede a todas las funciones premium")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.85))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(16)
            .background(
                LinearGradient(
                    colors: [accentHighlight, accentBlue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: glowColor.opacity(0.4), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
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
                settingsRow(
                    icon: "doc.text",
                    iconColor: accentBlue,
                    title: "Términos de uso",
                    showDivider: true
                ) {
                    showingTermsOfService = true
                }

                // Políticas de privacidad
                settingsRow(
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
                        .foregroundColor(.orange)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Notificaciones")
                        .font(.body)
                        .foregroundColor(.primary)

                    Text("Recordatorios de pasos pendientes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .tint(accentBlue)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
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
                                .foregroundColor(.red)
                        }
                        
                        Text("Cerrar sesión")
                            .font(.body)
                            .foregroundColor(.red)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
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
                .foregroundColor(accentBlue)
            
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
        }
    }
    
    private func settingsRow(icon: String, iconColor: Color, title: String, showDivider: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(iconColor.opacity(0.1))
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(iconColor)
                    }
                    
                    Text(title)
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(.tertiaryLabel))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                
                if showDivider {
                    Divider()
                        .padding(.leading, 56)
                }
            }
        }
        .buttonStyle(.plain)
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

// MARK: - Terms of Service View
struct TermsOfServiceView: View {
    @Environment(\.dismiss) private var dismiss
    
    private let accentBlue = Color(red: 0.0, green: 0.48, blue: 1.0)
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Términos de Uso de StepKit")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Última actualización: Octubre 2024")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        termSection(number: "1", title: "Aceptación de los términos", content: "Al usar StepKit, aceptas estos términos de uso. Si no estás de acuerdo, no uses la aplicación.")
                        
                        termSection(number: "2", title: "Uso de la aplicación", content: "StepKit está diseñado para ayudarte a gestionar y alcanzar tus objetivos personales. Debes usar la aplicación de manera responsable y legal.")
                        
                        termSection(number: "3", title: "Privacidad", content: "Respetamos tu privacidad. Para más información, consulta nuestras Políticas de Privacidad.")
                        
                        termSection(number: "4", title: "Limitación de responsabilidad", content: "StepKit se proporciona 'tal como está'. No garantizamos que el servicio sea ininterrumpido o libre de errores.")
                    }
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Términos de Uso")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cerrar") {
                        dismiss()
                    }
                    .foregroundColor(accentBlue)
                }
            }
        }
    }
    
    private func termSection(number: String, title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(number). \(title)")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Privacy Policy View
struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    
    private let accentBlue = Color(red: 0.0, green: 0.48, blue: 1.0)
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Políticas de Privacidad")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Última actualización: Octubre 2024")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        policySection(number: "1", title: "Información que recopilamos", content: "Recopilamos información que nos proporcionas directamente, como tus objetivos, progreso y preferencias dentro de la aplicación.")
                        
                        policySection(number: "2", title: "Cómo usamos tu información", content: "Utilizamos tu información para proporcionarte el servicio, mejorar la aplicación y personalizar tu experiencia.")
                        
                        policySection(number: "3", title: "Compartir información", content: "No vendemos, intercambiamos ni transferimos tu información personal a terceros sin tu consentimiento.")
                        
                        policySection(number: "4", title: "Seguridad", content: "Implementamos medidas de seguridad apropiadas para proteger tu información personal.")
                        
                        policySection(number: "5", title: "Contacto", content: "Si tienes preguntas sobre estas políticas, contáctanos a través de la aplicación.")
                    }
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Políticas de Privacidad")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cerrar") {
                        dismiss()
                    }
                    .foregroundColor(accentBlue)
                }
            }
        }
    }
    
    private func policySection(number: String, title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(number). \(title)")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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




