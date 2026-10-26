
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
    @Environment(\.apiClient) private var apiClient

    @State private var viewModel = SubscriptionViewModel()
    @State private var showingTermsOfService = false
    @State private var showingPrivacyPolicy = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header con icono premium
                headerSection

                // Error message
                if let error = viewModel.errorMessage {
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
        .alert("Suscripcion activada", isPresented: $viewModel.showSuccessAlert) {
            Button("Continuar") {
                dismiss()
            }
        } message: {
            Text("Tu suscripcion a StepKit Pro esta activa. Disfruta de todas las funciones premium.")
        }
        .sheet(isPresented: $showingTermsOfService) {
            TermsOfServiceView()
        }
        .sheet(isPresented: $showingPrivacyPolicy) {
            PrivacyPolicyView()
        }
    }

    // MARK: - Error Banner
    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .accessibilityHidden(true)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.primary)

            Spacer()

            Button {
                viewModel.errorMessage = nil
            } label: {
                Image(systemName: "xmark")
                    .foregroundColor(.secondary)
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("Cerrar mensaje de error")
            .accessibilityHint("Oculta este mensaje de error")
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error: \(message)")
        .accessibilityAddTraits(.updatesFrequently)
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
                    .accessibilityHidden(true)
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
                    .accessibilityHidden(true)

                Text("Beneficios Premium")
                    .font(.headline)
                    .foregroundColor(.primary)
            }

            VStack(spacing: 0) {
                FeatureRow(
                    icon: "infinity",
                    iconColor: .accentColor,
                    title: String(localized: "Objetivos ilimitados"),
                    description: String(localized: "Crea tantos objetivos como quieras"),
                    showDivider: true
                )

                FeatureRow(
                    icon: "sparkles",
                    iconColor: .purple,
                    title: String(localized: "IA sin limites"),
                    description: String(localized: "Genera planes con IA de forma ilimitada"),
                    showDivider: true
                )

                FeatureRow(
                    icon: "icloud",
                    iconColor: .accentHighlight,
                    title: String(localized: "Sincronizacion en la nube"),
                    description: String(localized: "Accede desde cualquier dispositivo"),
                    showDivider: true
                )

                FeatureRow(
                    icon: "bell.badge",
                    iconColor: .orange,
                    title: String(localized: "Recordatorios personalizados"),
                    description: String(localized: "Notificaciones inteligentes adaptadas"),
                    showDivider: true
                )

                FeatureRow(
                    icon: "chart.line.uptrend.xyaxis",
                    iconColor: .green,
                    title: String(localized: "Analisis avanzado"),
                    description: String(localized: "Estadisticas detalladas de tu progreso"),
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
                    .accessibilityHidden(true)

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
                .accessibilityLabel("Cargando planes de suscripción")
                .accessibilityAddTraits(.updatesFrequently)
            } else {
                VStack(spacing: 12) {
                    // Plan anual (recomendado)
                    PlanCard(
                        plan: .yearly,
                        product: storeKitManager.yearlyProduct,
                        isSelected: viewModel.selectedPlan == .yearly
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.selectedPlan = .yearly
                        }
                    }

                    // Plan mensual
                    PlanCard(
                        plan: .monthly,
                        product: storeKitManager.monthlyProduct,
                        isSelected: viewModel.selectedPlan == .monthly
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.selectedPlan = .monthly
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
                await viewModel.subscribeToPlan(
                    storeKitManager: storeKitManager,
                    apiClient: apiClient,
                    authManager: authManager
                )
            }
        } label: {
            HStack(spacing: 8) {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "sparkles")
                        .font(.body.weight(.semibold))
                }

                Text(viewModel.isLoading ? String(localized: "Procesando...") : String(localized: "Comenzar prueba gratuita"))
                    .font(.body.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                viewModel.isLoading
                    ? LinearGradient.disabledGradient
                    : LinearGradient.accentGradient
            )
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: viewModel.isLoading ? .clear : Color.glowColor.opacity(0.4), radius: 12, x: 0, y: 6)
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(viewModel.isLoading ? String(localized: "Procesando suscripción") : String(localized: "Comenzar prueba gratuita"))
        .accessibilityValue(viewModel.isLoading ? String(localized: "Procesando") : selectedProduct == nil ? String(localized: "No disponible") : "")
        .accessibilityHint("Inicia el proceso de suscripción al plan seleccionado")
        .disabled(viewModel.isLoading || selectedProduct == nil)
    }

    // MARK: - Restore Button
    private var restoreButton: some View {
        Button {
            Task {
                await viewModel.restorePurchases(
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
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Restaurar compras")
        .accessibilityHint("Restaura las compras anteriores realizadas desde este dispositivo")
        .disabled(viewModel.isLoading)
    }

    // MARK: - Legal Text
    private var legalText: some View {
        VStack(spacing: 8) {
            Text("7 dias gratis, despues \(viewModel.selectedPlan.displayPrice(from: selectedProduct))")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Text("Cancela en cualquier momento desde la App Store")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 4) {
                Button("Términos de uso") {
                    showingTermsOfService = true
                }
                .font(.caption)
                .foregroundColor(.accentColor)
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("Abre los términos de uso")
                
                Text("y")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button("Política de privacidad") {
                    showingPrivacyPolicy = true
                }
                .font(.caption)
                .foregroundColor(.accentColor)
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("Abre la política de privacidad")
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Helpers

    private var selectedProduct: Product? {
        switch viewModel.selectedPlan {
        case .monthly:
            return storeKitManager.monthlyProduct
        case .yearly:
            return storeKitManager.yearlyProduct
        }
    }
}

// MARK: - Subscription Plan
enum SubscriptionPlan: CaseIterable {
    case monthly
    case yearly

    var title: String {
        switch self {
        case .monthly:
            return String(localized: "Mensual")
        case .yearly:
            return String(localized: "Anual")
        }
    }

    var productId: String {
        switch self {
        case .monthly:
            return StoreKitManager.monthlyProductId
        case .yearly:
            return StoreKitManager.yearlyProductId
        }
    }

    func displayPrice(from product: Product?) -> String {
        guard let product = product else {
            return self == .monthly ? "4,99/mes" : "3,33/mes"
        }
        if self == .yearly {
            // Calculate monthly price for yearly
            let monthlyPrice = product.price / 12
            let currencyCode = Locale.current.currency?.identifier ?? "EUR"
            return "\(monthlyPrice.formatted(.currency(code: currencyCode)))/mes"
        }
        return "\(product.displayPrice)/mes"
    }

    func billingInfo(from product: Product?) -> String {
        guard let product = product else {
            return self == .monthly ? String(localized: "Facturado mensualmente") : String(localized: "39,99 facturado anualmente")
        }
        switch self {
        case .monthly:
            return String(localized: "Facturado mensualmente")
        case .yearly:
            return "\(product.displayPrice) facturado anualmente"
        }
    }

    var savings: String? {
        switch self {
        case .monthly:
            return nil
        case .yearly:
            return String(localized: "Ahorra 33%")
        }
    }

    var isPopular: Bool {
        self == .yearly
    }
}

// MARK: - Feature Row
struct FeatureRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let showDivider: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(iconColor.opacity(0.1))
                        .frame(width: 36, height: 36)

                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(iconColor)
                        .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(title). \(description)")

                Spacer()

                Image(systemName: "checkmark")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.green)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            if showDivider {
                Divider()
                    .padding(.leading, 62)
            }
        }
    }
}

// MARK: - Plan Card
struct PlanCard: View {
    let plan: SubscriptionPlan
    let product: Product?
    let isSelected: Bool
    let action: () -> Void

    private var planAccessibilityLabel: String {
        var label = "Plan \(plan.title)"
        if plan.isPopular {
            label += ", Popular"
        }
        label += ", \(plan.billingInfo(from: product))"
        label += ", \(plan.displayPrice(from: product))"
        if let savings = plan.savings {
            label += ", \(savings)"
        }
        if isSelected {
            label += ", Seleccionado"
        }
        return label
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                // Radio button
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.accentColor : Color(.systemGray4), lineWidth: 2)
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Circle()
                            .fill(LinearGradient.accentGradient)
                            .frame(width: 14, height: 14)
                    }
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(plan.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)

                        if plan.isPopular {
                            Text("POPULAR")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(LinearGradient.accentGradient)
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                        }
                    }

                    Text(plan.billingInfo(from: product))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(plan.displayPrice(from: product))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    if let savings = plan.savings {
                        Text(savings)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isSelected
                            ? LinearGradient.accentGradient
                            : LinearGradient.disabledGradient,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .accessibilityElement(children: .ignore)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityLabel(planAccessibilityLabel)
        .accessibilityHint("Toca dos veces para seleccionar este plan de suscripción")
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        SubscriptionView()
            .environment(AuthManager())
            .environment(\.apiClient, MockAPIClient())
    }
}
#endif
