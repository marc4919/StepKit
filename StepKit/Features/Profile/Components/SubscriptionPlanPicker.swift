//
//  SubscriptionPlanPicker.swift
//  StepKit
//
//  Extracted from SubscriptionView.swift
//

import SwiftUI
import StoreKit

// MARK: - Plan Option Card

struct PlanOptionCard: View {
    let plan: SubscriptionPlan
    let product: Product?
    let isSelected: Bool
    let action: () -> Void

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

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(plan.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)

                        if plan.isPopular {
                            Text("POPULAR")
                                .font(.caption2)
                                .bold()
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(LinearGradient.accentGradient)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                    }

                    Text(plan.billingInfo(from: product))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(plan.displayPrice(from: product))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    if let savings = plan.savings {
                        Text(savings)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.green)
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
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Subscription Plan Picker

struct SubscriptionPlanPicker: View {
    @Binding var selectedPlan: SubscriptionPlan
    let monthlyProduct: Product?
    let yearlyProduct: Product?
    let isLoading: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "creditcard")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.accentColor)

                Text("Elige tu plan")
                    .font(.headline)
                    .foregroundStyle(.primary)
            }

            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding()
                    Spacer()
                }
            } else {
                VStack(spacing: 12) {
                    // Plan anual (recomendado)
                    PlanOptionCard(
                        plan: .yearly,
                        product: yearlyProduct,
                        isSelected: selectedPlan == .yearly
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedPlan = .yearly
                        }
                    }

                    // Plan mensual
                    PlanOptionCard(
                        plan: .monthly,
                        product: monthlyProduct,
                        isSelected: selectedPlan == .monthly
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
}
