//
//  PlanCard.swift
//  StepKit
//
//  Created by Assistant on 14/12/25.
//

import SwiftUI
import StoreKit

struct PlanCard: View {
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
        }
        .buttonStyle(.plain)
    }
}
