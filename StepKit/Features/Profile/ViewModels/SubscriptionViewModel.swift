import SwiftUI
import StoreKit

/// The StoreKit operations needed by the subscription flow, injectable in tests.
@MainActor
protocol SubscriptionPurchasing {
    var hasActiveSubscription: Bool { get }
    func isProductAvailable(for plan: SubscriptionPlan) -> Bool
    func purchaseSubscription(plan: SubscriptionPlan, appAccountToken: UUID) async throws -> String
    func restorePurchases() async
    func getOriginalTransactionId() async -> String?
}

extension StoreKitManager: SubscriptionPurchasing {
    func isProductAvailable(for plan: SubscriptionPlan) -> Bool {
        product(for: plan) != nil
    }

    func purchaseSubscription(plan: SubscriptionPlan, appAccountToken: UUID) async throws -> String {
        guard let product = product(for: plan) else { throw StoreKitError.productUnavailable }
        let transaction = try await purchase(product, appAccountToken: appAccountToken)
        return String(transaction.originalID)
    }

    private func product(for plan: SubscriptionPlan) -> Product? {
        switch plan {
        case .monthly: monthlyProduct
        case .yearly: yearlyProduct
        }
    }
}

@Observable
@MainActor
final class SubscriptionViewModel {
    var selectedPlan: SubscriptionPlan = .yearly
    var isLoading = false
    var errorMessage: String?
    var showSuccessAlert = false

    func subscribeToPlan(storeKitManager: any SubscriptionPurchasing, apiClient: any APIClientProtocol, authManager: any AuthManaging) async {
        guard !isLoading, !Task.isCancelled else { return }
        guard storeKitManager.isProductAvailable(for: selectedPlan) else {
            errorMessage = String(localized: "Producto no disponible")
            return
        }
        guard let session = Session(authManager) else {
            errorMessage = String(localized: "Necesitas una sesión válida para suscribirte")
            return
        }

        isLoading = true
        errorMessage = nil
        showSuccessAlert = false
        defer { isLoading = false }

        do {
            let transactionID = try await storeKitManager.purchaseSubscription(
                plan: selectedPlan, appAccountToken: session.userID
            )
            guard session.isCurrent(authManager), !Task.isCancelled else { return }
            try await verifyAndRefresh(transactionID: transactionID, session: session, apiClient: apiClient, authManager: authManager)
        } catch StoreKitError.userCancelled {
            // Cancelling the purchase is not an error for the user.
        } catch {
            guard session.isCurrent(authManager), !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
        }
    }

    func restorePurchases(storeKitManager: any SubscriptionPurchasing, apiClient: any APIClientProtocol, authManager: any AuthManaging) async {
        guard !isLoading, !Task.isCancelled else { return }
        // Capture before AppStore.sync; never adopt a new login midway through a restore.
        guard let session = Session(authManager) else {
            errorMessage = String(localized: "Necesitas una sesión válida para restaurar compras")
            return
        }

        isLoading = true
        errorMessage = nil
        showSuccessAlert = false
        defer { isLoading = false }

        await storeKitManager.restorePurchases()
        guard session.isCurrent(authManager), !Task.isCancelled else { return }
        guard storeKitManager.hasActiveSubscription else {
            errorMessage = String(localized: "No se encontraron compras anteriores")
            return
        }
        let transactionID = await storeKitManager.getOriginalTransactionId()
        guard session.isCurrent(authManager), !Task.isCancelled else { return }
        guard let transactionID else {
            errorMessage = String(localized: "No se encontraron compras anteriores")
            return
        }

        do {
            try await verifyAndRefresh(transactionID: transactionID, session: session, apiClient: apiClient, authManager: authManager)
        } catch {
            guard session.isCurrent(authManager), !Task.isCancelled else { return }
            errorMessage = String(localized: "Error al verificar la suscripcion: \(error.localizedDescription)")
        }
    }

    private func verifyAndRefresh(transactionID: String, session: Session, apiClient: any APIClientProtocol, authManager: any AuthManaging) async throws {
        _ = try await apiClient.verifySubscription(transactionId: transactionID, token: session.token)
        guard session.isCurrent(authManager), !Task.isCancelled else { return }
        let updatedUser = try await apiClient.getUserProfile(token: session.token)
        guard session.isCurrent(authManager), !Task.isCancelled else { return }
        guard updatedUser.uuid == session.userID else { throw APIError.invalidResponse }
        // No suspension between the final check and the memory/Keychain update.
        authManager.updateUser(updatedUser)
        showSuccessAlert = true
    }

    private struct Session {
        let id: UUID
        let userID: UUID
        let token: String

        init?(_ auth: any AuthManaging) {
            guard auth.isAuthenticated, let userID = auth.currentUser?.uuid,
                  let token = auth.token, !token.isEmpty else { return nil }
            id = auth.sessionID
            self.userID = userID
            self.token = token
        }

        func isCurrent(_ auth: any AuthManaging) -> Bool {
            auth.isAuthenticated && auth.sessionID == id
                && auth.currentUser?.uuid == userID && auth.token == token
        }
    }
}
