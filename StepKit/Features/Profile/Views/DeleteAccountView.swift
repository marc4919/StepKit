//
//  DeleteAccountView.swift
//  StepKit
//
//  Eliminar la cuenta desde la app (App Review 5.1.1(v)). Como en Ajustes y en la
//  mayoría de apps: una pantalla propia que explica qué se borra, qué pasa con la
//  suscripción y, al final, una confirmación en el centro antes de pedirla a Apple.
//

import SwiftUI
import StoreKit

struct DeleteAccountView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.apiClient) private var apiClient: any APIClientProtocol
    @Environment(\.syncManager) private var syncManager
    @State private var confirming = false
    @State private var deleting = false
    @State private var errorMessage: String?
    @State private var showingSubscriptions = false

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    IconChip(symbol: "trash.fill", color: .red, size: 44)
                    Text("Eliminar cuenta").font(.largeTitle.bold())
                    Text("Se borra tu cuenta de StepKit y todo lo que has guardado en ella. No se puede deshacer.")
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)
            }
            Section("Qué se borra") {
                Label("Tus Kits, pasos y avances", systemImage: Symbols.kits)
                Label("Tus sesiones reservadas", systemImage: Symbols.calendar)
                Label("El vínculo con tu Apple Account", systemImage: "apple.logo")
            }
            Section {
                Button("Gestionar suscripción") { showingSubscriptions = true }
            } header: {
                Text("StepKit Pro")
            } footer: {
                Text("Eliminar la cuenta no cancela la suscripción. Si tienes StepKit Pro, cancélala antes para que no se renueve.")
            }
            Section {
                Button(role: .destructive) { confirming = true } label: {
                    if deleting {
                        HStack { ProgressView(); Text("Eliminando cuenta…") }
                    } else {
                        Text("Eliminar cuenta")
                    }
                }
                .disabled(deleting)
                .accessibilityIdentifier("deleteAccount.confirm")
            } footer: {
                Text("Te pediremos que lo confirmes con Apple.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(alignment: .top) { BrandGlow() }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .manageSubscriptionsSheet(isPresented: $showingSubscriptions)
        // Alerta y no hoja de acciones: es la última confirmación de algo irreversible y sale igual en todos los tamaños.
        .alert("¿Eliminar tu cuenta?", isPresented: $confirming) {
            Button("Cancelar", role: .cancel) { }
            Button("Eliminar", role: .destructive) { Task { await deleteAccount() } }
        } message: {
            Text("Se borrarán tu cuenta y todos tus datos, aquí y en nuestro servidor.")
        }
        .alert("No se ha podido eliminar la cuenta", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @MainActor
    private func deleteAccount() async {
        guard let token = authManager.token else { return }
        deleting = true
        defer { deleting = false }
        do {
            try await AccountDeletionService.deleteAccount(token: token, apiClient: apiClient,
                                                           authentication: authManager, syncManager: syncManager)
        } catch AccountDeletionService.Failure.cancelled {
            // La persona no ha confirmado con Apple: no se borra nada.
        } catch AccountDeletionService.Failure.appleFailed {
            errorMessage = String(localized: "Apple no ha podido confirmar tu identidad. Inténtalo de nuevo.")
        } catch {
            errorMessage = String(localized: "Comprueba tu conexión e inténtalo de nuevo. Tu cuenta no se ha borrado.")
        }
    }
}
