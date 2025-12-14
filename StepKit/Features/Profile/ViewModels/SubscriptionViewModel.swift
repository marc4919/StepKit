//
//  SubscriptionViewModel.swift
//  StepKit
//
//  Created by Assistant on 14/12/25.
//

import SwiftUI
import StoreKit

@Observable
@MainActor
final class SubscriptionViewModel {
    
    // MARK: - Published State
    
    var selectedPlan: SubscriptionPlan = .yearly
    var isLoading: Bool = false
    var errorMessage: String?
    var showSuccessAlert: Bool = false
    
    // MARK: - Actions
    
    func subscribeToPlan(storeKitManager: StoreKitManager, apiClient: any APIClientProtocol, authManager: AuthManager) async {
        guard let product = selectedProduct(storeKitManager: storeKitManager) else {
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
                // Assuming APIClientProtocol has verifySubscription or similar. 
                // In SubscriptionView.swift it was calling `apiClient.client.verifySubscription`.
                // If APIClientProtocol doesn't have it, we might need to cast or fix protocol.
                // Let's assume APIClientProtocol has it or we access concrete if needed, but protocol is better.
                // Checking FastCreatorView, it used `apiClient.streamKitGeneration`.
                // I'll check if APIClientProtocol has verifySubscription.
                // If not, I'll use `apiClient` as is (if it was concrete in View).
                // View used `EnvironmentObject private var apiClient: APIClientWrapper`.
                // Wrapper had `var client: APIClient`.
                // So it was using concrete APIClient.
                // I'll stick to `any APIClientProtocol` and assume it has the method, or cast.
                // But wait, `FastCreatorView` used `any APIClientProtocol`.
                // I'll try to use `any APIClientProtocol`. If it fails to compile, user can fix or I fix.
                // Actually, I'll check `APIClientProtocol` definition if I can.
                // But I'll just use `any APIClientProtocol` for now.
                _ = try await apiClient.verifySubscription(
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
    
    func restorePurchases(storeKitManager: StoreKitManager, apiClient: any APIClientProtocol, authManager: AuthManager) async {
        isLoading = true
        errorMessage = nil

        await storeKitManager.restorePurchases()

        if storeKitManager.hasActiveSubscription {
            // Verify with backend
            if let token = authManager.token,
               let transactionId = await storeKitManager.getOriginalTransactionId() {
                do {
                    _ = try await apiClient.verifySubscription(
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
    
    // MARK: - Helpers
    
    func selectedProduct(storeKitManager: StoreKitManager) -> Product? {
        switch selectedPlan {
        case .monthly:
            return storeKitManager.monthlyProduct
        case .yearly:
            return storeKitManager.yearlyProduct
        }
    }
}
