//
//  AIConsentView.swift
//  StepKit
//
//  Permiso explícito antes de enviar datos a IA de terceros (App Review 5.1.2(i)).
//  Se muestra justo antes del primer envío (crear un Kit), no al abrir la app.
//

import SwiftUI

struct AIConsentView: View {
    /// `true` si el usuario dio permiso; `false` si eligió «Ahora no».
    var onComplete: (Bool) -> Void

    @Environment(AIConsentManager.self) private var consentManager
    @State private var hasAccepted = false
    @State private var showingPrivacyPolicy = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        IconChip(symbol: "sparkles", color: .accentColor, size: 44)
                        Text("Antes de preparar tu plan")
                            .font(.title2.bold())
                            .accessibilityAddTraits(.isHeader)
                        Text("Para proponerte los pasos, StepKit envía lo que escribas sobre tu objetivo a un servicio de inteligencia artificial de otra empresa, a través de nuestro servidor.")
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 6)
                }
                Section("Qué se envía") {
                    Label("Tu objetivo y la fecha que quieres", systemImage: Symbols.kits)
                    Label("El tiempo que tienes disponible", systemImage: Symbols.time)
                    Label("Los obstáculos que menciones", systemImage: Symbols.risk)
                }
                Section {
                    Label("No se usa para publicidad ni se vende", systemImage: "hand.raised")
                    Label("Puedes retirar el permiso en Perfil", systemImage: "person.crop.circle")
                    Button("Leer la Política de privacidad") { showingPrivacyPolicy = true }
                        .accessibilityIdentifier("consent.privacyPolicy")
                } header: {
                    Text("Tu control")
                } footer: {
                    Text("Sin este permiso puedes seguir usando StepKit, pero no crear planes con IA.")
                }
                Section {
                    Toggle("Acepto compartir estos datos con el servicio de IA", isOn: $hasAccepted)
                        .accessibilityIdentifier("consent.accept")
                        .accessibilityValue(hasAccepted ? "Aceptado" : "No aceptado")
                }
            }
            .navigationTitle("Uso de IA")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Ahora no") { onComplete(false) }
                        .accessibilityIdentifier("consent.decline")
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    consentManager.giveConsent()
                    onComplete(true)
                } label: {
                    Text("Permitir y preparar el plan").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!hasAccepted)
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(.bar)
                .accessibilityIdentifier("consent.continue")
            }
            .sheet(isPresented: $showingPrivacyPolicy) {
                PrivacyPolicyView()
            }
        }
    }
}

#Preview {
    AIConsentView { _ in }
        .environment(AIConsentManager())
}
