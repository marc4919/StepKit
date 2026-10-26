import StoreKit
import SwiftUI

/// Manages StoreKit 2 subscriptions for StepKit Pro
@Observable
@MainActor
final class StoreKitManager {
    // MARK: - Product IDs

    static let monthlyProductId = "com.stepkit.premium.monthly"
    static let yearlyProductId = "com.stepkit.premium.yearly"

    private static let productIds: Set<String> = [monthlyProductId, yearlyProductId]

    // MARK: - Published State

    private(set) var products: [Product] = []
    private(set) var purchasedProductIDs: Set<String> = []
    private(set) var isLoading = false
    private(set) var error: Error?

    // MARK: - Computed Properties

    var monthlyProduct: Product? {
        products.first { $0.id == Self.monthlyProductId }
    }

    var yearlyProduct: Product? {
        products.first { $0.id == Self.yearlyProductId }
    }

    var hasActiveSubscription: Bool {
        !purchasedProductIDs.isEmpty
    }

    // MARK: - Private

    private var transactionListener: Task<Void, Never>?

    // MARK: - Lifecycle

    init() {
        transactionListener = listenForTransactions()
    }

    // MARK: - Public Methods

    /// Loads available products from App Store
    func loadProducts() async {
        isLoading = true
        error = nil

        do {
            products = try await Product.products(for: Self.productIds)
                .sorted { $0.price < $1.price }
            await updatePurchasedProducts()
        } catch {
            self.error = error
            #if DEBUG
            print("StoreKit products load failed: type=\(String(describing: type(of: error)))")
            #endif
        }

        isLoading = false
    }

    /// Purchases a subscription product
    /// - Parameters:
    ///   - product: The product to purchase.
    ///   - appAccountToken: Stable StepKit account UUID signed into the transaction.
    /// - Returns: The verified transaction if successful
    func purchase(
        _ product: Product,
        appAccountToken: UUID
    ) async throws -> StoreKit.Transaction {
        isLoading = true
        error = nil

        defer { isLoading = false }

        let result = try await product.purchase(
            options: [.appAccountToken(appAccountToken)]
        )

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await updatePurchasedProducts()
            return transaction

        case .userCancelled:
            throw StoreKitError.userCancelled

        case .pending:
            throw StoreKitError.pending

        @unknown default:
            throw StoreKitError.unknown
        }
    }

    /// Restores previous purchases
    func restorePurchases() async {
        isLoading = true
        error = nil

        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
        } catch {
            self.error = error
            #if DEBUG
            print("StoreKit restore failed: type=\(String(describing: type(of: error)))")
            #endif
        }

        isLoading = false
    }

    /// Updates the set of purchased product IDs
    func updatePurchasedProducts() async {
        var purchased: Set<String> = []

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }

            if transaction.revocationDate == nil {
                purchased.insert(transaction.productID)
            }
        }

        purchasedProductIDs = purchased
    }

    /// Gets the current subscription status
    func getSubscriptionStatus() async -> SubscriptionStatus? {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }

            if Self.productIds.contains(transaction.productID) {
                return SubscriptionStatus(
                    productId: transaction.productID,
                    expirationDate: transaction.expirationDate,
                    isActive: transaction.revocationDate == nil,
                    originalTransactionId: String(transaction.originalID)
                )
            }
        }
        return nil
    }

    /// Gets the original transaction ID for verification with backend
    func getOriginalTransactionId() async -> String? {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }

            if Self.productIds.contains(transaction.productID) {
                return String(transaction.originalID)
            }
        }
        return nil
    }

    // MARK: - Private Methods

    private func listenForTransactions() -> Task<Void, Never> {
        Task(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                guard let self = self else { break }
                await self.handleTransactionUpdate(result)
            }
        }
    }

    private func handleTransactionUpdate(_ result: VerificationResult<StoreKit.Transaction>) async {
        do {
            let transaction: StoreKit.Transaction = try checkVerified(result)
            await updatePurchasedProducts()
            await transaction.finish()
        } catch {
            #if DEBUG
            print("StoreKit verification failed: type=\(String(describing: type(of: error)))")
            #endif
        }
    }

    private nonisolated func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreKitError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }
}

// MARK: - Supporting Types

struct SubscriptionStatus {
    let productId: String
    let expirationDate: Date?
    let isActive: Bool
    let originalTransactionId: String
}

enum StoreKitError: LocalizedError {
    case productUnavailable
    case userCancelled
    case pending
    case verificationFailed
    case unknown

    var errorDescription: String? {
        switch self {
        case .productUnavailable: SubscriptionText.string("paywall.error.unavailable")
        case .userCancelled: SubscriptionText.string("paywall.error.cancelled")
        case .pending: SubscriptionText.string("paywall.error.pending")
        case .verificationFailed: SubscriptionText.string("paywall.error.verification")
        case .unknown: SubscriptionText.string("paywall.error.unknown")
        }
    }
}

// MARK: - Environment Key

private struct StoreKitManagerKey: EnvironmentKey {
    @MainActor static let defaultValue = StoreKitManager()
}

extension EnvironmentValues {
    var storeKitManager: StoreKitManager {
        get { self[StoreKitManagerKey.self] }
        set { self[StoreKitManagerKey.self] = newValue }
    }
}
