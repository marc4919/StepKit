//
//  SubscriptionView.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on 14/10/25.
//

import SwiftUI
import StoreKit
import Combine

struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.storeKitManager) private var storeKitManager
    @Environment(AuthManager.self) private var authManager
    @Environment(\.apiClient) private var apiClient: any APIClientProtocol

    @State private var vm = SubscriptionViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header con icono premium
                headerSection

                // Error message
                if let error = vm.errorMessage {
                    errorBanner(error)
                }

                // Beneficios
                benefitsSection

                // Planes de suscripcion
                plansSection

                // Boton de suscripcion
                subscribeButton

                // Restaurar compras
                restoreButton

                // Texto legal
                legalText

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Suscripcion")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await storeKitManager.loadProducts()
        }
        .alert("Suscripcion activada", isPresented: $vm.showSuccessAlert) {
            Button("Continuar") {
                dismiss()
            }
        } message: {
            Text("Tu suscripcion a StepKit Pro esta activa. Disfruta de todas las funciones premium.")
        }
    }

    // MARK: - Error Banner
    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.primary)

            Spacer()

            Button {
                vm.errorMessage = nil
            } label: {
                Image(systemName: "xmark")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Icono premium con glow
            ZStack {
                // Glow exterior
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.accentHighlight.opacity(0.3), Color.accentColor.opacity(0.1), .clear],
                            center: .center,
                            startRadius: 30,
                            endRadius: 70
                        )
                    )
                    .frame(width: 120, height: 120)

                // Circulo de fondo
                Circle()
                    .fill(LinearGradient.accentWithOpacity( 0.2))
                    .frame(width: 88, height: 88)

                // Corona
                Image(systemName: "crown.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.yellow, Color.orange],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: Color.orange.opacity(0.5), radius: 8, x: 0, y: 4)
            }

            VStack(spacing: 6) {
                Text("StepKit Pro")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Text("Desbloquea todo el potencial")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 16)
    }

    // MARK: - Benefits Section
    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.accentColor)

                Text("Beneficios Premium")
                    .font(.headline)
                    .foregroundColor(.primary)
            }

            VStack(spacing: 0) {
                FeatureRow(
                    icon: "infinity",
                    iconColor: .accentColor,
                    title: "Objetivos ilimitados",
                    description: "Crea tantos objetivos como quieras",
                    showDivider: true
                )

                FeatureRow(
                    icon: "sparkles",
                    iconColor: .purple,
                    title: "IA sin limites",
                    description: "Genera planes con IA de forma ilimitada",
                    showDivider: true
                )

                FeatureRow(
                    icon: "icloud",
                    iconColor: .accentHighlight,
                    title: "Sincronizacion en la nube",
                    description: "Accede desde cualquier dispositivo",
                    showDivider: true
                )

                FeatureRow(
                    icon: "bell.badge",
                    iconColor: .orange,
                    title: "Recordatorios personalizados",
                    description: "Notificaciones inteligentes adaptadas",
                    showDivider: true
                )

                FeatureRow(
                    icon: "chart.line.uptrend.xyaxis",
                    iconColor: .green,
                    title: "Analisis avanzado",
                    description: "Estadisticas detalladas de tu progreso",
                    showDivider: false
                )
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Plans Section
    private var plansSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "creditcard")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.accentColor)

                Text("Elige tu plan")
                    .font(.headline)
                    .foregroundColor(.primary)
            }

            if storeKitManager.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding()
                    Spacer()
                }
            } else {
                VStack(spacing: 12) {
                    // Plan anual (recomendado)
                    PlanCard(
                        plan: .yearly,
                        product: storeKitManager.yearlyProduct,
                        isSelected: vm.selectedPlan == .yearly
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            vm.selectedPlan = .yearly
                        }
                    }

                    // Plan mensual
                    PlanCard(
                        plan: .monthly,
                        product: storeKitManager.monthlyProduct,
                        isSelected: vm.selectedPlan == .monthly
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            vm.selectedPlan = .monthly
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Subscribe Button
    private var subscribeButton: some View {
        Button {
            Task {
                await vm.subscribeToPlan(
                    storeKitManager: storeKitManager,
                    apiClient: apiClient,
                    authManager: authManager
                )
            }
        } label: {
            HStack(spacing: 8) {
                if vm.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "sparkles")
                        .font(.body.weight(.semibold))
                }

                Text(vm.isLoading ? "Procesando..." : "Comenzar prueba gratuita")
                    .font(.body.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                vm.isLoading
                    ? LinearGradient.disabledGradient
                    : LinearGradient.accentGradient
            )
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: vm.isLoading ? .clear : Color.glowColor.opacity(0.4), radius: 12, x: 0, y: 6)
        }
        .disabled(vm.isLoading || vm.selectedProduct(storeKitManager: storeKitManager) == nil)
    }

    // MARK: - Restore Button
    private var restoreButton: some View {
        Button {
            Task {
                await vm.restorePurchases(
                    storeKitManager: storeKitManager,
                    apiClient: apiClient,
                    authManager: authManager
                )
            }
        } label: {
            Text("Restaurar compras")
                .font(.subheadline)
                .foregroundColor(.accentColor)
        }
        .disabled(vm.isLoading)
    }

    // MARK: - Legal Text
    private var legalText: some View {
        VStack(spacing: 6) {
            Text("7 dias gratis, despues \(vm.selectedPlan.displayPrice(from: vm.selectedProduct(storeKitManager: storeKitManager)))")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)

            Text("Cancela en cualquier momento desde la App Store")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

#Preview {
    NavigationStack {
        SubscriptionView()
            .environment(AuthManager())
            .environment(\.apiClient, MockAPIClient())
    }
}
