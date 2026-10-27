//
//  ProfileView.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on 14/10/25.
//
//  Perfil v4.4: lista del sistema con cabecera de identidad, suscripción,
//  recordatorios, IA y privacidad, información y cierre de sesión.
//

import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(AuthManager.self) private var authManager
    @Query(filter: #Predicate<GoalEntity> { !$0.isDeleted }) private var goalEntities: [GoalEntity]
    @State private var showingTermsOfService = false
    @State private var showingPrivacyPolicy = false
    @State private var showingSignOutAlert = false
    @State private var showingDemoReset = false
    @State private var resettingDemo = false
    @Environment(\.modelContext) private var modelContext
    @Environment(\.syncManager) private var syncManager

    private var visibleKits: [GoalEntity] {
        guard let ownerID = authManager.currentUser?.id else { return [] }
        return goalEntities.filter { $0.ownerID == ownerID }
    }

    @State private var twoColumns = false
    @Environment(\.openURL) private var openURL

    @ViewBuilder private var headerSection: some View {
        Section {
            header.listRowBackground(Color.clear)
        }
    }

    @ViewBuilder private var accountSection: some View {
        Section {
            NavigationLink { SubscriptionView() } label: {
                ProfileRow(title: String(localized: "Suscripción"), detail: displayTier, symbol: "crown.fill", color: .orange)
            }
            NavigationLink { RemindersSettingsView() } label: {
                ProfileRow(title: String(localized: "Recordatorios"), symbol: "bell.fill", color: .red)
            }
            NavigationLink { AIPrivacyView() } label: {
                ProfileRow(title: String(localized: "IA y privacidad"), symbol: "hand.raised.fill", color: .blue)
            }
            .accessibilityIdentifier("profile.aiPrivacy")
            // El idioma de cada app se elige en Ajustes de iOS (como recomienda Apple); aquí se abre directamente.
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            } label: {
                ProfileRow(title: String(localized: "Idioma"), detail: AppLanguage.displayName,
                           symbol: "globe", color: .indigo)
            }
            .buttonStyle(.plain)
            .accessibilityHint(String(localized: "Abre los ajustes de StepKit para cambiar el idioma"))
            .accessibilityIdentifier("profile.language")
        }
    }

    @ViewBuilder private var infoSection: some View {
        Section("Información") {
            Button { showingTermsOfService = true } label: {
                ProfileRow(title: String(localized: "Términos de uso"), symbol: "doc.text.fill", color: .gray)
            }
            .buttonStyle(.plain)
            Button { showingPrivacyPolicy = true } label: {
                ProfileRow(title: String(localized: "Política de privacidad"), symbol: "lock.fill", color: .green)
            }
            .buttonStyle(.plain)
            NavigationLink { AboutView() } label: {
                ProfileRow(title: String(localized: "Acerca de StepKit"), symbol: "info", color: .accentColor)
            }
        }
    }

    @ViewBuilder private var debugSection: some View {
        #if DEBUG
        Section {
            Button {
                showingDemoReset = true
            } label: {
                if resettingDemo {
                    HStack { ProgressView(); Text("Restaurando…") }
                } else {
                    Label("Restaurar demo", systemImage: "arrow.counterclockwise")
                }
            }
            .disabled(resettingDemo)
            .accessibilityIdentifier("profile.resetDemo")
            // Unida al botón: el diálogo sale de él (popover en iPad y el Duo abierto, hoja abajo en iPhone).
            .confirmationDialog("¿Restaurar la demo?", isPresented: $showingDemoReset, titleVisibility: .visible) {
                Button("Borrar todo y empezar de cero", role: .destructive) {
                    Task { await resetDemo() }
                }
            } message: {
                Text("Se borrarán tus Kits, avances y sesiones de esta cuenta, aquí y en el servidor de pruebas. Después se cerrará la sesión y verás la bienvenida.")
            }
        } footer: {
            Text("Solo en versiones de prueba. Borra tus Kits de esta cuenta, cierra la sesión y vuelve a la bienvenida para enseñar la app desde cero.")
        }
        #endif
    }

    @ViewBuilder private var signOutSection: some View {
        Section {
            Button("Cerrar sesión", role: .destructive) { showingSignOutAlert = true }
                .accessibilityIdentifier("profile.signOut")
                .accessibilityHint("Cierra la sesión actual y regresa a la pantalla de inicio de sesión")
        }
        Section {
            // Como en Ajustes: borrar la cuenta tiene su propia pantalla que explica qué se pierde.
            NavigationLink { DeleteAccountView() } label: {
                Text("Eliminar cuenta").foregroundStyle(.red)
            }
            .accessibilityIdentifier("profile.deleteAccount")
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if twoColumns {
                    // iPhone Duo abierto en horizontal o iPad: tu cuenta a la izquierda, información a la derecha.
                    HStack(alignment: .top, spacing: 16) {
                        List {
                            headerSection
                            accountSection
                            signOutSection
                        }
                        List {
                            infoSection
                            debugSection
                        }
                    }
                    .frame(maxWidth: 1100)
                    .frame(maxWidth: .infinity)
                    .balancedHorizontalSafeArea()
                } else {
                    List {
                        headerSection
                        accountSection
                        infoSection
                        debugSection
                        signOutSection
                    }
                    .readableContentWidth()
                }
            }
            .onGeometryChange(for: Bool.self) { $0.size.width >= 760 && $0.size.width > $0.size.height } action: { twoColumns = $0 }
            .scrollContentBackground(.hidden)
            .background(alignment: .top) { BrandGlow() }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Perfil")
            .sheet(isPresented: $showingTermsOfService) { TermsOfServiceView() }
            .sheet(isPresented: $showingPrivacyPolicy) { PrivacyPolicyView() }
            .alert("Cerrar sesión", isPresented: $showingSignOutAlert) {
                Button("Cancelar", role: .cancel) { }
                Button("Cerrar sesión", role: .destructive) { authManager.signOut() }
            } message: {
                Text("Podrás volver a entrar con tu Apple Account. Tus Kits se conservan.")
            }
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            Text(initials)
                .font(.title2.bold())
                .foregroundStyle(.white)
                .frame(width: 72, height: 72)
                .background(RadialGradient(colors: [Color(red: 0.55, green: 0.82, blue: 1.0), .accentColor,
                                                    Color(red: 0.0, green: 0.36, blue: 0.85)],
                                           center: UnitPoint(x: 0.35, y: 0.3), startRadius: 4, endRadius: 60),
                            in: .circle)
                .shadow(color: Color.accentColor.opacity(0.35), radius: 10, y: 4)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(displayName).font(.title.bold())
                Text("Sesión iniciada con Apple").foregroundStyle(.secondary)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 6) { chips }
                    VStack(alignment: .leading, spacing: 6) { chips }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var chips: some View {
        MetaChip(symbol: Symbols.kits, text: visibleKits.count == 1 ? String(localized: "1 Kit") : String(localized: "\(visibleKits.count) Kits"),
                 color: .accentColor)
        let done = visibleKits.filter { $0.resultConfirmedAt != nil }.count
        if done > 0 {
            MetaChip(symbol: "checkmark.circle", text: done == 1 ? String(localized: "1 terminado") : String(localized: "\(done) terminados"),
                     color: MetaTint.done)
        }
    }

    #if DEBUG
    /// Deja la app como recién instalada para enseñarla: borra los Kits de la cuenta en el
    /// servidor (tombstones por sync), limpia todo lo local y vuelve a la bienvenida.
    @MainActor
    private func resetDemo() async {
        resettingDemo = true
        defer { resettingDemo = false }
        for kit in visibleKits {
            kit.markAsDeleted()
        }
        try? modelContext.save()
        if let syncManager {
            await syncManager.cancelAndWaitForSync()
            await syncManager.forceSync()
            syncManager.stopAutoSync()
        }
        NotificationService.shared.cancelAllNotifications()
        try? E2ELocalStateResetter().reset(authentication: authManager)
        // La bienvenida se observa con @AppStorage: se fija explícitamente tras limpiar el dominio.
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
    }
    #endif

    // MARK: - Derived Properties

    private var displayName: String {
        if let name = authManager.displayName,
           !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return name
        }
        return String(localized: "Tu perfil")
    }

    private var initials: String {
        let letters = displayName.split(separator: " ").prefix(2).compactMap(\.first)
        let value = String(letters).uppercased()
        return value.isEmpty || displayName == String(localized: "Tu perfil") ? "SK" : value
    }

    private var displayTier: String {
        authManager.currentUser?.isPremium == true ? "Pro" : SubscriptionText.string("paywall.compare.free")
    }
}

/// Fila de ajustes: icono en círculo de color, título y detalle opcional.
struct ProfileRow: View {
    var title: String
    var detail: String?
    var symbol: String
    var color: Color

    var body: some View {
        LabeledContent {
            if let detail { Text(detail) }
        } label: {
            Label { Text(title).foregroundStyle(.primary) } icon: { IconChip(symbol: symbol, color: color, size: 28) }
        }
        .contentShape(.rect)
    }
}

// MARK: - Recordatorios

struct RemindersSettingsView: View {
    @AppStorage("globalNotificationsEnabled") private var globalNotificationsEnabled = true

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    IconChip(symbol: "bell.fill", color: .red, size: 44)
                    Text("Recordatorios").font(.largeTitle.bold())
                    Text("Avisos para volver a tus pasos y a tus sesiones reservadas.").foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)
            }
            Section {
                Toggle(isOn: $globalNotificationsEnabled) {
                    Label { Text("Recordatorios de StepKit") } icon: { IconChip(symbol: "bell", color: .red, size: 28) }
                }
                .onChange(of: globalNotificationsEnabled) { _, enabled in
                    if enabled {
                        Task { await NotificationService.shared.requestAuthorizationIfNeeded() }
                    } else {
                        NotificationService.shared.cancelAllNotifications()
                    }
                }
            } footer: {
                Text("Cada paso puede desactivar su recordatorio. StepKit pide permiso de notificaciones la primera vez que hace falta.")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - IA y privacidad

struct AIPrivacyView: View {
    @Environment(AIConsentManager.self) private var consentManager
    @State private var aiConsentGiven = false
    @State private var showingPrivacyPolicy = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    OrbitMark(height: 90).frame(maxWidth: 200)
                    Text(String(localized: "Tú decides cómo\nrecibir ayuda")).font(.largeTitle.bold())
                    Text("Revisas cualquier plan o propuesta antes de aplicarlo.").foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)
            }
            Section {
                Toggle(isOn: Binding(
                    get: { aiConsentGiven },
                    set: { granted in
                        if granted { consentManager.giveConsent() } else { consentManager.revokeConsent() }
                        aiConsentGiven = granted
                    }
                )) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("IA externa para planes y asistente")
                            Text(aiConsentGiven ? String(localized: "Permitido") : String(localized: "Se pedirá al crear un Kit"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        IconChip(symbol: "sparkles", color: .orange, size: 28)
                    }
                }
                .accessibilityIdentifier("profile.aiConsent")
            } footer: {
                Text("Al crear un Kit o escribir al asistente del Kit, tu objetivo, tu plan, tus avances y lo que escribas se envían a un servicio de IA de otra empresa a través de nuestro servidor. Puedes retirar el permiso cuando quieras.")
            }
            Section {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Asistente del Kit")
                        Text("Usa el servicio de IA externo, así que solo funciona con este permiso. Sin él, tus Kits y tu calendario funcionan igual.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    IconChip(symbol: Symbols.assistant, color: .accentColor, size: 28)
                }
            }
            Section("Tu control") {
                Label { Text("Revisas cada plan antes de aceptarlo") } icon: { IconChip(symbol: "doc.text.magnifyingglass", color: .accentColor, size: 28) }
                Label { Text("Puedes descartar cualquier propuesta") } icon: { IconChip(symbol: "trash", color: .red, size: 28) }
                Label { Text("Puedes seguir tu plan sin ayuda") } icon: { IconChip(symbol: "figure.walk", color: .green, size: 28) }
            }
            Section { Button("Leer la Política de privacidad") { showingPrivacyPolicy = true } }
        }
        .scrollContentBackground(.hidden)
        .background(alignment: .top) { BrandGlow() }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { aiConsentGiven = consentManager.hasConsent }
        .sheet(isPresented: $showingPrivacyPolicy) { PrivacyPolicyView() }
    }
}

// MARK: - Acerca de

struct AboutView: View {
    private var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(short) (\(build))"
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    OrbitMark(height: 170)
                    (Text("Step").foregroundStyle(.primary) + Text("Kit").foregroundStyle(.tint))
                        .font(.largeTitle.bold())
                    Text("Un paso claro para volver").font(.title3.bold())
                    Text("Da forma a un objetivo, guarda lo que avanzas y retoma con una acción concreta.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }
            Section {
                LabeledContent("Versión", value: version)
            }
        }
        .scrollContentBackground(.hidden)
        .background(alignment: .top) { BrandGlow() }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    ProfileView()
        .environment(AuthManager())
        .environment(AIConsentManager())
}
