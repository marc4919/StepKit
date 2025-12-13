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
    @EnvironmentObject private var apiClient: APIClientWrapper

    @State private var selectedPlan: SubscriptionPlan = .yearly
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccessAlert = false

    // Colores del tema (consistente con otras vistas)
    private let accentBlue = Color(red: 0.0, green: 0.48, blue: 1.0)
    private let accentHighlight = Color(red: 0.55, green: 0.82, blue: 1.0)
    private let glowColor = Color(red: 0.2, green: 0.6, blue: 1.0)

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header con icono premium
                headerSection

                // Error message
                if let error = errorMessage {
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
        .alert("Suscripcion activada", isPresented: $showSuccessAlert) {
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
                errorMessage = nil
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
                            colors: [accentHighlight.opacity(0.3), accentBlue.opacity(0.1), .clear],
                            center: .center,
                            startRadius: 30,
                            endRadius: 70
                        )
                    )
                    .frame(width: 120, height: 120)

                // Circulo de fondo
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [accentHighlight.opacity(0.2), accentBlue.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
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
                    .foregroundColor(accentBlue)

                Text("Beneficios Premium")
                    .font(.headline)
                    .foregroundColor(.primary)
            }

            VStack(spacing: 0) {
                FeatureRow(
                    icon: "infinity",
                    iconColor: accentBlue,
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
                    iconColor: accentHighlight,
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
                    .foregroundColor(accentBlue)

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
                        isSelected: selectedPlan == .yearly,
                        accentBlue: accentBlue,
                        accentHighlight: accentHighlight
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedPlan = .yearly
                        }
                    }

                    // Plan mensual
                    PlanCard(
                        plan: .monthly,
                        product: storeKitManager.monthlyProduct,
                        isSelected: selectedPlan == .monthly,
                        accentBlue: accentBlue,
                        accentHighlight: accentHighlight
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedPlan = .monthly
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
                await subscribeToPlan()
            }
        } label: {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "sparkles")
                        .font(.body.weight(.semibold))
                }

                Text(isLoading ? "Procesando..." : "Comenzar prueba gratuita")
                    .font(.body.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: isLoading ? [Color.gray.opacity(0.5), Color.gray.opacity(0.4)] : [accentHighlight, accentBlue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: isLoading ? .clear : glowColor.opacity(0.4), radius: 12, x: 0, y: 6)
        }
        .disabled(isLoading || selectedProduct == nil)
    }

    // MARK: - Restore Button
    private var restoreButton: some View {
        Button {
            Task {
                await restorePurchases()
            }
        } label: {
            Text("Restaurar compras")
                .font(.subheadline)
                .foregroundColor(accentBlue)
        }
        .disabled(isLoading)
    }

    // MARK: - Legal Text
    private var legalText: some View {
        VStack(spacing: 6) {
            Text("7 dias gratis, despues \(selectedPlan.displayPrice(from: selectedProduct))")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)

            Text("Cancela en cualquier momento desde la App Store")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Helpers

    private var selectedProduct: Product? {
        switch selectedPlan {
        case .monthly:
            return storeKitManager.monthlyProduct
        case .yearly:
            return storeKitManager.yearlyProduct
        }
    }

    private func subscribeToPlan() async {
        guard let product = selectedProduct else {
            errorMessage = "Producto no disponible"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            // 1. Purchase with StoreKit
            let transaction = try await storeKitManager.purchase(product)

            // 2. Verify with backend
            if let token = authManager.token {
                let transactionId = String(transaction.originalID)
                _ = try await apiClient.client.verifySubscription(
                    transactionId: transactionId,
                    token: token
                )

                // 3. Refresh user info
                // TODO: Refresh auth manager with new user info
            }

            showSuccessAlert = true
        } catch StoreKitError.userCancelled {
            // User cancelled, no error message needed
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func restorePurchases() async {
        isLoading = true
        errorMessage = nil

        await storeKitManager.restorePurchases()

        if storeKitManager.hasActiveSubscription {
            // Verify with backend
            if let token = authManager.token,
               let transactionId = await storeKitManager.getOriginalTransactionId() {
                do {
                    _ = try await apiClient.client.verifySubscription(
                        transactionId: transactionId,
                        token: token
                    )
                    showSuccessAlert = true
                } catch {
                    errorMessage = "Error al verificar la suscripcion: \(error.localizedDescription)"
                }
            }
        } else {
            errorMessage = "No se encontraron compras anteriores"
        }

        isLoading = false
    }
}

// MARK: - Subscription Plan
enum SubscriptionPlan: CaseIterable {
    case monthly
    case yearly

    var title: String {
        switch self {
        case .monthly:
            return "Mensual"
        case .yearly:
            return "Anual"
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
            return self == .monthly ? "Facturado mensualmente" : "39,99 facturado anualmente"
        }
        switch self {
        case .monthly:
            return "Facturado mensualmente"
        case .yearly:
            return "\(product.displayPrice) facturado anualmente"
        }
    }

    var savings: String? {
        switch self {
        case .monthly:
            return nil
        case .yearly:
            return "Ahorra 33%"
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

                Spacer()

                Image(systemName: "checkmark")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.green)
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
    let accentBlue: Color
    let accentHighlight: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                // Radio button
                ZStack {
                    Circle()
                        .stroke(isSelected ? accentBlue : Color(.systemGray4), lineWidth: 2)
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [accentHighlight, accentBlue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 14, height: 14)
                    }
                }

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
                                .background(
                                    LinearGradient(
                                        colors: [accentHighlight, accentBlue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
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
                            ? LinearGradient(colors: [accentHighlight, accentBlue], startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [Color(.systemGray5), Color(.systemGray5)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - API Client Wrapper for Environment
final class APIClientWrapper: ObservableObject {
    @Published private(set) var client: APIClient

    init(client: APIClient = APIClient()) {
        self.client = client
    }
}

#Preview {
    NavigationStack {
        SubscriptionView()
            .environment(AuthManager())
            .environmentObject(APIClientWrapper())
    }
}

