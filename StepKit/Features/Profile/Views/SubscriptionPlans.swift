//
//  SubscriptionPlans.swift
//  StepKit
//

import SwiftUI
import StoreKit

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

struct PlanFeature: Identifiable {
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

struct PlanValueView: View {
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

struct UsageRow: View {
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

struct PlanRow: View {
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
