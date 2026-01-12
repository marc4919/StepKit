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
    
    func subscribeToPlan(storeKitManager: StoreKitManager, apiClient: any APIClientProtocol, authManager: any AuthManaging) async {
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
                
                // Verify subscription
                _ = try await apiClient.verifySubscription(
                    transactionId: transactionId,
                    token: token
                )

                // 3. Refresh user info
                let updatedUser = try await apiClient.getUserProfile(token: token)
                authManager.updateUser(updatedUser)
            }

            showSuccessAlert = true
        } catch StoreKitError.userCancelled {
            // User cancelled, no error message needed
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
    
    func restorePurchases(storeKitManager: StoreKitManager, apiClient: any APIClientProtocol, authManager: any AuthManaging) async {
        isLoading = true
        errorMessage = nil

        await storeKitManager.restorePurchases()

        if storeKitManager.hasActiveSubscription {
            // Verify with backend
            if let token = authManager.token,
               let transactionId = await storeKitManager.getOriginalTransactionId() {
                do {
                    // Verify subscription
                    _ = try await apiClient.verifySubscription(
                        transactionId: transactionId,
                        token: token
                    )
                    
                    // Refresh user info
                    let updatedUser = try await apiClient.getUserProfile(token: token)
                    authManager.updateUser(updatedUser)
                    
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
