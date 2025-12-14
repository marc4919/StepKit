//
//  AIUsageIndicator.swift
//  StepKit
//
//  Indicador suave del uso de IA para usuarios free
//

import SwiftUI

/// Indicador de uso de IA para usuarios gratuitos
/// Muestra el contador de llamadas restantes con colores suaves
struct AIUsageIndicator: View {
    let used: Int
    let quota: Int
    let isPremium: Bool

    private var remaining: Int {
        max(0, quota - used)
    }

    private var usageLevel: UsageLevel {
        if isPremium { return .premium }
        if remaining == 0 { return .exhausted }
        if remaining <= 4 { return .critical }
        if remaining <= 10 { return .low }
        return .normal
    }

    var body: some View {
        if isPremium {
            // Premium users don't see this indicator
            EmptyView()
        } else {
            indicatorView
        }
    }

    @ViewBuilder
    private var indicatorView: some View {
        switch usageLevel {
        case .normal, .low, .critical:
            normalIndicator
        case .exhausted:
            exhaustedIndicator
        case .premium:
            EmptyView()
        }
    }

    private var normalIndicator: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.subheadline)
                .foregroundColor(usageLevel.iconColor)

            Text("IA disponible este mes: \(remaining) / \(quota)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(usageLevel.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var exhaustedIndicator: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.subheadline)
                    .foregroundColor(.gray)

                Text("Has usado toda la ayuda IA de este mes")
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }

            Text("Premium desbloquea acompanamiento continuo.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Usage Level

private enum UsageLevel {
    case normal     // > 10 remaining
    case low        // 5-10 remaining
    case critical   // 1-4 remaining
    case exhausted  // 0 remaining
    case premium    // Unlimited

    var iconColor: Color {
        switch self {
        case .normal:
            return .green
        case .low:
            return Color(red: 0.9, green: 0.7, blue: 0.2) // Soft yellow
        case .critical:
            return Color(red: 0.95, green: 0.6, blue: 0.3) // Soft orange
        case .exhausted:
            return .gray
        case .premium:
            return .purple
        }
    }

    var backgroundColor: Color {
        switch self {
        case .normal:
            return Color.green.opacity(0.1)
        case .low:
            return Color(red: 0.9, green: 0.7, blue: 0.2).opacity(0.1)
        case .critical:
            return Color(red: 0.95, green: 0.6, blue: 0.3).opacity(0.1)
        case .exhausted:
            return Color(.systemGray6)
        case .premium:
            return Color.purple.opacity(0.1)
        }
    }
}

// MARK: - Compact Variant

/// Variante compacta para usar en barras de navegacion o espacios reducidos
struct AIUsageIndicatorCompact: View {
    let used: Int
    let quota: Int
    let isPremium: Bool

    private var remaining: Int {
        max(0, quota - used)
    }

    private var progress: Double {
        guard quota > 0 else { return 0 }
        return Double(used) / Double(quota)
    }

    private var color: Color {
        if isPremium { return .purple }
        if remaining == 0 { return .gray }
        if remaining <= 4 { return Color(red: 0.95, green: 0.6, blue: 0.3) }
        if remaining <= 10 { return Color(red: 0.9, green: 0.7, blue: 0.2) }
        return .green
    }

    var body: some View {
        if isPremium {
            EmptyView()
        } else {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundColor(color)

                Text("\(remaining)")
                    .font(.caption.monospacedDigit())
                    .fontWeight(.medium)
                    .foregroundColor(color)

                // Mini progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(.systemGray5))

                        RoundedRectangle(cornerRadius: 2)
                            .fill(color)
                            .frame(width: geometry.size.width * (1 - progress))
                    }
                }
                .frame(width: 30, height: 4)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
        }
    }
}

// MARK: - Previews

#Preview("Normal - Many remaining") {
    VStack(spacing: 20) {
        AIUsageIndicator(used: 5, quota: 20, isPremium: false)
        AIUsageIndicatorCompact(used: 5, quota: 20, isPremium: false)
    }
    .padding()
}

#Preview("Low - Few remaining") {
    VStack(spacing: 20) {
        AIUsageIndicator(used: 12, quota: 20, isPremium: false)
        AIUsageIndicatorCompact(used: 12, quota: 20, isPremium: false)
    }
    .padding()
}

#Preview("Critical - Very few remaining") {
    VStack(spacing: 20) {
        AIUsageIndicator(used: 18, quota: 20, isPremium: false)
        AIUsageIndicatorCompact(used: 18, quota: 20, isPremium: false)
    }
    .padding()
}

#Preview("Exhausted - None remaining") {
    VStack(spacing: 20) {
        AIUsageIndicator(used: 20, quota: 20, isPremium: false)
        AIUsageIndicatorCompact(used: 20, quota: 20, isPremium: false)
    }
    .padding()
}

#Preview("Premium - Hidden") {
    VStack(spacing: 20) {
        AIUsageIndicator(used: 100, quota: 20, isPremium: true)
        AIUsageIndicatorCompact(used: 100, quota: 20, isPremium: true)
        Text("Premium users don't see the indicator")
            .font(.caption)
            .foregroundColor(.secondary)
    }
    .padding()
}
