//
//  SubscriptionView.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on 14/10/25.
//
//  StepKit Pro v4.4: qué incluye cada plan, cuánto has usado este mes y la compra.
//  Precio, periodo y prueba gratuita salen siempre de la App Store, nunca del código.
//

import SwiftUI
import StoreKit

struct SubscriptionView: View {
    /// Límite del plan gratuito que ha llevado hasta aquí; nil cuando se abre desde Perfil.
    var reason: PlanLimitReason?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.storeKitManager) private var storeKitManager
    @Environment(AuthManager.self) private var authManager
    @Environment(\.apiClient) private var apiClient

    @State private var viewModel = SubscriptionViewModel()
    /// Ofertas de introducción a las que esta cuenta todavía tiene derecho, por plan.
    @State private var introOffers: [SubscriptionPlan: Product.SubscriptionOffer] = [:]
    @State private var renewalDate: Date?
    @State private var showingManage = false
    @State private var showingOfferCode = false
    @State private var showingTermsOfService = false
    @State private var showingPrivacyPolicy = false

    init(reason: PlanLimitReason? = nil) {
        self.reason = reason
    }

    private var isPro: Bool {
        storeKitManager.hasActiveSubscription || authManager.currentUser?.isPremium == true
    }

    var body: some View {
        List {
            headerSection
            if let reason, !isPro { limitSection(reason) }
            if !isPro { usageSection }
            compareSection
            if isPro { manageSection } else { plansSection }
            linksSection
        }
        .readableContentWidth()
        .scrollContentBackground(.hidden)
        .background(alignment: .top) { BrandGlow() }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("StepKit Pro")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if !isPro { purchaseBar }
        }
        .toolbar {
            if reason != nil {
                ToolbarItem(placement: .cancellationAction) {
                    Button(SubscriptionText.string("paywall.close")) { dismiss() }
                }
            }
        }
        .task {
            await storeKitManager.loadProducts()
            await loadOffersAndRenewal()
            await viewModel.refreshUsage(apiClient: apiClient, authManager: authManager)
        }
        .onChange(of: storeKitManager.hasActiveSubscription) {
            Task { await loadOffersAndRenewal() }
        }
        .alert(SubscriptionText.string("paywall.success.title"), isPresented: $viewModel.showSuccessAlert) {
            Button(SubscriptionText.string("paywall.success.continue")) { dismiss() }
        } message: {
            Text(SubscriptionText.string("paywall.success.message"))
        }
        .alert(SubscriptionText.string("paywall.error.title"), isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .manageSubscriptionsSheet(isPresented: $showingManage)
        .offerCodeRedemption(isPresented: $showingOfferCode)
        .sheet(isPresented: $showingTermsOfService) { TermsOfServiceView() }
        .sheet(isPresented: $showingPrivacyPolicy) { PrivacyPolicyView() }
    }

    // MARK: - Cabecera

    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                // Sin halo: la fila lo recortaría en un cuadrado; ya está BrandGlow detrás de la lista.
                BrandSphere(size: 56, glow: false)
                Eyebrow(text: "StepKit Pro")
                Text(SubscriptionText.string(isPro ? "paywall.header.pro.title" : "paywall.header.title"))
                    .font(.largeTitle.bold())
                Text(headerSubtitle).foregroundStyle(.secondary)
            }
            .padding(.top, 8)
            .listRowBackground(Color.clear)
            .accessibilityElement(children: .combine)
        }
    }

    private var headerSubtitle: String {
        guard isPro else { return SubscriptionText.string("paywall.header.subtitle") }
        if let renewalDate {
            let date = renewalDate.formatted(.dateTime.day().month(.wide).year().locale(SubscriptionText.locale))
            return SubscriptionText.string("paywall.header.pro.renews \(date)")
        }
        return SubscriptionText.string("paywall.header.pro.subtitle")
    }

    // MARK: - Límite alcanzado

    private func limitSection(_ reason: PlanLimitReason) -> some View {
        Section {
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text(reason.title(limit: limit(for: reason))).font(.headline)
                    Text(reason.message).font(.subheadline).foregroundStyle(.secondary)
                }
            } icon: {
                IconChip(symbol: reason.symbol, color: .orange, size: 34)
            }
            .padding(.vertical, 4)
            .listRowBackground(Color.orange.opacity(0.12))
        }
    }

    private func limit(for reason: PlanLimitReason) -> Int {
        switch reason {
        case .activeKits: PlanLimits.freeActiveKits
        case .cloudAI: authManager.currentUser?.monthlyAICallsQuota ?? PlanLimits.freeCloudAIPerMonth
        }
    }

    // MARK: - Uso de este mes

    @ViewBuilder private var usageSection: some View {
        let user = authManager.currentUser
        if user?.activeKitsCount != nil || user?.monthlyAICalls != nil {
            Section {
                if let used = user?.activeKitsCount {
                    UsageRow(title: SubscriptionText.string("paywall.usage.kits"),
                             symbol: Symbols.kits, color: .accentColor,
                             used: used, limit: PlanLimits.freeActiveKits)
                }
                if let used = user?.monthlyAICalls {
                    UsageRow(title: SubscriptionText.string("paywall.usage.ai"),
                             symbol: "sparkles", color: .purple,
                             used: used, limit: user?.monthlyAICallsQuota ?? PlanLimits.freeCloudAIPerMonth)
                }
            } header: {
                Text(SubscriptionText.string("paywall.usage.header"))
            } footer: {
                Text(SubscriptionText.string("paywall.usage.footer"))
            }
        }
    }

    // MARK: - Comparación

    private var compareSection: some View {
        Section {
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 14) {
                GridRow {
                    Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                    Text(SubscriptionText.string("paywall.compare.free"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 52)
                    Text("Pro")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 52)
                }
                .accessibilityHidden(true)
                ForEach(PlanFeature.all) { feature in
                    GridRow {
                        Label {
                            Text(feature.title).font(.subheadline)
                                .fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            IconChip(symbol: feature.symbol, color: feature.color, size: 28)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        PlanValueView(value: feature.free)
                        PlanValueView(value: feature.pro, emphasized: true)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(feature.title)
                    .accessibilityValue(feature.accessibilityValue)
                }
            }
            .padding(.vertical, 6)
        } header: {
            Text(SubscriptionText.string("paywall.compare.header"))
        } footer: {
            Text(SubscriptionText.string("paywall.compare.footer"))
        }
    }

    // MARK: - Planes

    private var plansSection: some View {
        Section {
            if storeKitManager.isLoading && storeKitManager.products.isEmpty {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .accessibilityLabel(SubscriptionText.string("paywall.plans.loading"))
            } else if storeKitManager.products.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(SubscriptionText.string("paywall.plans.unavailable"))
                        .foregroundStyle(.secondary)
                    Button(SubscriptionText.string("paywall.plans.retry")) {
                        Task {
                            await storeKitManager.loadProducts()
                            await loadOffersAndRenewal()
                        }
                    }
                }
            } else {
                ForEach([SubscriptionPlan.yearly, .monthly], id: \.self) { plan in
                    if let product = product(for: plan) {
                        PlanRow(plan: plan,
                                product: product,
                                savingsPercent: plan == .yearly ? yearlySavingsPercent : nil,
                                trial: introOffers[plan].map { SubscriptionText.trialText($0) },
                                isSelected: viewModel.selectedPlan == plan) {
                            withAnimation(.snappy) { viewModel.selectedPlan = plan }
                        }
                    }
                }
            }
        } header: {
            Text(SubscriptionText.string("paywall.plans.header"))
        } footer: {
            Text(SubscriptionText.string("paywall.plans.legal"))
        }
    }

    // MARK: - Gestión (Pro)

    private var manageSection: some View {
        Section {
            Button {
                showingManage = true
            } label: {
                Label {
                    Text(SubscriptionText.string("paywall.manage")).foregroundStyle(.primary)
                } icon: {
                    IconChip(symbol: "creditcard.fill", color: .accentColor, size: 28)
                }
            }
        } footer: {
            Text(SubscriptionText.string("paywall.manage.footer"))
        }
    }

    // MARK: - Enlaces

    private var linksSection: some View {
        Section {
            Button(SubscriptionText.string("paywall.restore")) {
                Task {
                    await viewModel.restorePurchases(storeKitManager: storeKitManager,
                                                     apiClient: apiClient,
                                                     authManager: authManager)
                }
            }
            .disabled(viewModel.isLoading)
            if !isPro {
                Button(SubscriptionText.string("paywall.offerCode")) { showingOfferCode = true }
            }
            Button(SubscriptionText.string("paywall.terms")) { showingTermsOfService = true }
            Button(SubscriptionText.string("paywall.privacy")) { showingPrivacyPolicy = true }
        }
    }

    // MARK: - Barra de compra

    private var purchaseBar: some View {
        VStack(spacing: 8) {
            Button {
                Task {
                    await viewModel.subscribeToPlan(storeKitManager: storeKitManager,
                                                    apiClient: apiClient,
                                                    authManager: authManager)
                }
            } label: {
                Group {
                    if viewModel.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text(ctaTitle).font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 30)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .disabled(viewModel.isLoading || selectedProduct == nil)
            .accessibilityIdentifier("subscription.subscribe")

            if let caption = ctaCaption {
                Text(caption)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .frame(maxWidth: 680)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    private var ctaTitle: String {
        if let offer = introOffers[viewModel.selectedPlan], offer.paymentMode == .freeTrial {
            return SubscriptionText.string("paywall.cta.trial \(SubscriptionText.duration(offer.period))")
        }
        return SubscriptionText.string("paywall.cta.subscribe")
    }

    /// Lo que se pagará después: obligatorio junto al botón según las normas de la App Store.
    private var ctaCaption: String? {
        guard let product = selectedProduct else {
            return storeKitManager.isLoading ? nil : SubscriptionText.string("paywall.plans.unavailable")
        }
        let price = SubscriptionText.pricePerPeriod(product)
        if introOffers[viewModel.selectedPlan]?.paymentMode == .freeTrial {
            return SubscriptionText.string("paywall.cta.caption.trial \(price)")
        }
        return SubscriptionText.string("paywall.cta.caption \(price)")
    }

    // MARK: - Datos

    private var selectedProduct: Product? { product(for: viewModel.selectedPlan) }

    private func product(for plan: SubscriptionPlan) -> Product? {
        switch plan {
        case .monthly: storeKitManager.monthlyProduct
        case .yearly: storeKitManager.yearlyProduct
        }
    }

    /// Ahorro real del plan anual frente a doce meses del mensual, con los precios de la tienda.
    private var yearlySavingsPercent: Int? {
        guard let monthly = storeKitManager.monthlyProduct?.price,
              let yearly = storeKitManager.yearlyProduct?.price, monthly > 0 else { return nil }
        let ratio = NSDecimalNumber(decimal: yearly / (monthly * 12)).doubleValue
        let percent = Int(((1 - ratio) * 100).rounded())
        return percent >= 5 ? percent : nil
    }

    private func loadOffersAndRenewal() async {
        var offers: [SubscriptionPlan: Product.SubscriptionOffer] = [:]
        for plan in SubscriptionPlan.allCases {
            guard let subscription = product(for: plan)?.subscription,
                  let offer = subscription.introductoryOffer,
                  await subscription.isEligibleForIntroOffer else { continue }
            offers[plan] = offer
        }
        introOffers = offers
        renewalDate = await storeKitManager.getSubscriptionStatus()?.expirationDate
    }
}

// MARK: - Plan

enum SubscriptionPlan: CaseIterable {
    case monthly
    case yearly

    var title: String {
        switch self {
        case .monthly: SubscriptionText.string("paywall.plan.monthly")
        case .yearly: SubscriptionText.string("paywall.plan.yearly")
        }
    }

    var productId: String {
        switch self {
        case .monthly: StoreKitManager.monthlyProductId
        case .yearly: StoreKitManager.yearlyProductId
        }
    }
}

// MARK: - Límites del plan gratuito

/// Límites del plan gratuito. El servidor los aplica; la app solo los explica.
enum PlanLimits {
    static let freeActiveKits = 2
    /// Valor por defecto si el perfil aún no ha llegado; manda `monthlyAICallsQuota` del servidor.
    static let freeCloudAIPerMonth = 10
}

/// Límite que se ha tocado al intentar algo con el plan gratuito.
enum PlanLimitReason: String, Identifiable {
    case activeKits
    case cloudAI

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .activeKits: Symbols.kits
        case .cloudAI: "sparkles"
        }
    }

    func title(limit: Int) -> String {
        switch self {
        case .activeKits: SubscriptionText.string("paywall.limit.kits.title \(String(limit))")
        case .cloudAI: SubscriptionText.string("paywall.limit.ai.title \(String(limit))")
        }
    }

    var message: String {
        switch self {
        case .activeKits: SubscriptionText.string("paywall.limit.kits.message")
        case .cloudAI: SubscriptionText.string("paywall.limit.ai.message")
        }
    }
}

// MARK: - Comparación

private struct PlanFeature: Identifiable {
    enum Value {
        case included
        case count(Int)
        case unlimited
    }

    let id: String
    let title: String
    let symbol: String
    let color: Color
    let free: Value
    let pro: Value

    var accessibilityValue: String {
        SubscriptionText.string("paywall.compare.a11y \(Self.describe(free)) \(Self.describe(pro))")
    }

    private static func describe(_ value: Value) -> String {
        switch value {
        case .included: SubscriptionText.string("paywall.compare.included")
        case .count(let n): String(n)
        case .unlimited: SubscriptionText.string("paywall.compare.unlimited")
        }
    }

    static var all: [PlanFeature] {
        [
            PlanFeature(id: "kits", title: SubscriptionText.string("paywall.feature.kits"),
                        symbol: Symbols.kits, color: .accentColor,
                        free: .count(PlanLimits.freeActiveKits), pro: .unlimited),
            PlanFeature(id: "ai", title: SubscriptionText.string("paywall.feature.ai"),
                        symbol: "sparkles", color: .purple,
                        free: .count(PlanLimits.freeCloudAIPerMonth), pro: .unlimited),
            PlanFeature(id: "calendar", title: SubscriptionText.string("paywall.feature.calendar"),
                        symbol: Symbols.session, color: .orange, free: .included, pro: .included),
            PlanFeature(id: "reminders", title: SubscriptionText.string("paywall.feature.reminders"),
                        symbol: "bell.fill", color: .red, free: .included, pro: .included),
            PlanFeature(id: "sync", title: SubscriptionText.string("paywall.feature.sync"),
                        symbol: "arrow.triangle.2.circlepath", color: .green, free: .included, pro: .included)
        ]
    }
}

private struct PlanValueView: View {
    let value: PlanFeature.Value
    var emphasized = false

    var body: some View {
        Group {
            switch value {
            case .included:
                Image(systemName: "checkmark").fontWeight(.semibold)
                    .foregroundStyle(emphasized ? Color.accentColor : Color.secondary)
            case .count(let n):
                Text(String(n)).monospacedDigit().fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            case .unlimited:
                Image(systemName: "infinity").fontWeight(.bold)
                    .foregroundStyle(Color.accentColor)
            }
        }
        .font(.subheadline)
        .frame(width: 52)
    }
}

// MARK: - Filas

private struct UsageRow: View {
    let title: String
    let symbol: String
    let color: Color
    let used: Int
    let limit: Int

    private var reached: Bool { used >= limit }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent {
                Text(SubscriptionText.string("paywall.usage.value \(String(min(used, limit))) \(String(limit))"))
                    .monospacedDigit()
                    .foregroundStyle(reached ? Color.orange : Color.secondary)
            } label: {
                Label { Text(title) } icon: { IconChip(symbol: symbol, color: color, size: 28) }
            }
            ProgressView(value: Double(min(used, limit)), total: Double(max(limit, 1)))
                .tint(reached ? .orange : color)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(SubscriptionText.string("paywall.usage.value \(String(min(used, limit))) \(String(limit))"))
    }
}

private struct PlanRow: View {
    let plan: SubscriptionPlan
    let product: Product
    let savingsPercent: Int?
    let trial: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? Color.accentColor : Color(.tertiaryLabel))
                    .contentTransition(.symbolEffect(.replace))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(plan.title).font(.headline)
                        if let savingsPercent {
                            Text(SubscriptionText.string("paywall.plan.savings \(String(savingsPercent))"))
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .foregroundStyle(.white)
                                .background(Color.accentColor, in: .capsule)
                        }
                    }
                    if let detail {
                        Text(detail).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                Text(SubscriptionText.pricePerPeriod(product))
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.trailing)
            }
            .contentShape(.rect)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .listRowBackground(isSelected ? Color.accentColor.opacity(0.10) : Color(.secondarySystemGroupedBackground))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("subscription.plan.\(plan == .yearly ? "yearly" : "monthly")")
    }

    /// «Equivale a 3,33 €/mes · 7 días gratis».
    private var detail: String? {
        var parts: [String] = []
        if plan == .yearly {
            let monthly = (product.price / 12).formatted(product.priceFormatStyle)
            parts.append(SubscriptionText.string("paywall.plan.yearly.perMonth \(monthly)"))
        }
        if let trial { parts.append(trial) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

// MARK: - Textos (español e inglés)

/// Textos de la suscripción en la tabla `Subscription` (español e inglés).
enum SubscriptionText {
    static func string(_ key: String.LocalizationValue) -> String {
        String(localized: key, table: "Subscription")
    }

    /// Idioma en el que se muestra la app, para fechas y periodos.
    static var locale: Locale {
        Locale(identifier: Bundle.main.preferredLocalizations.first ?? "en")
    }

    /// «7 días», «1 semana», «1 mes»…
    static func duration(_ period: Product.SubscriptionPeriod) -> String {
        var components = DateComponents()
        switch period.unit {
        case .day: components.day = period.value
        case .week: components.weekOfMonth = period.value
        case .month: components.month = period.value
        case .year: components.year = period.value
        @unknown default: components.day = period.value
        }
        let formatter = DateComponentsFormatter()
        var calendar = Calendar.current
        calendar.locale = locale
        formatter.calendar = calendar
        formatter.unitsStyle = .full
        formatter.allowedUnits = [.day, .weekOfMonth, .month, .year]
        return formatter.string(from: components) ?? ""
    }

    /// «4,99 €/mes» o «39,99 €/año».
    static func pricePerPeriod(_ product: Product) -> String {
        let price = product.displayPrice
        guard let period = product.subscription?.subscriptionPeriod else { return price }
        switch (period.unit, period.value) {
        case (.month, 1): return string("paywall.price.month \(price)")
        case (.year, 1): return string("paywall.price.year \(price)")
        default: return "\(price) / \(duration(period))"
        }
    }

    /// «7 días gratis» o el precio de la oferta de introducción.
    static func trialText(_ offer: Product.SubscriptionOffer) -> String {
        let length = duration(offer.period)
        switch offer.paymentMode {
        case .freeTrial: return string("paywall.offer.free \(length)")
        default: return string("paywall.offer.paid \(offer.displayPrice) \(length)")
        }
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
