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
    /// Para qué se pide: crear un plan o hablar con el asistente del Kit.
    enum Purpose { case plan, assistant }
    var purpose: Purpose = .plan
    var onComplete: (Bool) -> Void
    /// Solo en el asistente: cerrar sin enviar nada (el mensaje vuelve al campo de texto).
    var onCancel: (() -> Void)?

    @Environment(AIConsentManager.self) private var consentManager
    @State private var hasAccepted = false
    @State private var showingPrivacyPolicy = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        IconChip(symbol: "sparkles", color: .accentColor, size: 44)
                        Text(purpose == .plan ? LocalizedStringKey("Antes de preparar tu plan") : LocalizedStringKey("Antes de hablar con el asistente"))
                            .font(.title2.bold())
                            .accessibilityAddTraits(.isHeader)
                        Text("Para proponerte los pasos y ayudarte a ajustar el plan, StepKit envía lo que escribas sobre tu objetivo, y después tu plan y tus avances, a un servicio de inteligencia artificial de otra empresa, a través de nuestro servidor.")
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 6)
                }
                Section("Qué se envía") {
                    Label("Tu objetivo y la fecha que quieres", systemImage: Symbols.kits)
                    Label("El tiempo que tienes disponible", systemImage: Symbols.time)
                    Label("Los obstáculos que menciones", systemImage: Symbols.risk)
                    Label("Tu plan, tus avances y lo que escribas al asistente", systemImage: Symbols.assistant)
                }
                Section {
                    Label("No se usa para publicidad ni se vende", systemImage: "hand.raised")
                    Label("Puedes retirar el permiso en Perfil", systemImage: "person.crop.circle")
                    Button("Leer la Política de privacidad") { showingPrivacyPolicy = true }
                        .accessibilityIdentifier("consent.privacyPolicy")
                } header: {
                    Text("Tu control")
                } footer: {
                    if purpose == .plan {
                        Text("Sin este permiso puedes seguir usando StepKit, pero no crear planes con IA, y el asistente solo usará tu dispositivo.")
                    } else {
                        Text("Sin este permiso, el asistente responde con Apple Intelligence en tu dispositivo: es más limitado, pero no sale nada de tu iPhone. Puedes cambiarlo cuando quieras en Perfil.")
                    }
                }
                Section {
                    Toggle("Acepto compartir estos datos con el servicio de IA", isOn: $hasAccepted)
                        .accessibilityIdentifier("consent.accept")
                        .accessibilityValue(hasAccepted ? String(localized: "Aceptado") : String(localized: "No aceptado"))
                }
            }
            .navigationTitle("Uso de IA")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if purpose == .assistant, let onCancel {
                        Button("Cancelar", action: onCancel)
                    } else {
                        Button("Ahora no") { onComplete(false) }
                            .accessibilityIdentifier("consent.decline")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 4) {
                    Button {
                        consentManager.giveConsent()
                        onComplete(true)
                    } label: {
                        Text(purpose == .plan ? LocalizedStringKey("Permitir y preparar el plan") : LocalizedStringKey("Permitir y enviar")).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!hasAccepted)
                    .accessibilityIdentifier("consent.continue")
                    // En el asistente se puede seguir sin IA externa: responde el modelo del dispositivo.
                    if purpose == .assistant {
                        Button { onComplete(false) } label: {
                            Text("Usar solo mi dispositivo").frame(maxWidth: .infinity)
                        }
                        .controlSize(.large)
                        .accessibilityIdentifier("consent.deviceOnly")
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(.bar)
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
