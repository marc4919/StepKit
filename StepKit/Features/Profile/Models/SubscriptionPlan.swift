//
//  SubscriptionPlan.swift
//  StepKit
//
//  Created by Assistant on 14/12/25.
//

import Foundation
import StoreKit

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
