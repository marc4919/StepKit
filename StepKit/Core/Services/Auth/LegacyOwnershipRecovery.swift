//
//  LegacyOwnershipRecovery.swift
//  StepKit
//

import Foundation

@MainActor
protocol LegacyDataClaiming {
    func hasUnownedLegacyData() throws -> Bool
    func claimLegacyData(for ownerID: String) throws
}

/// Mantiene en cuarentena los registros anteriores a la introducción de ownership.
/// El primer usuario conocido queda anclado en Keychain y ese anclaje no puede ser
/// sustituido por otra cuenta. Solo se elimina después de persistir la reclamación.
@MainActor
final class LegacyOwnershipRecovery {
    enum PreparationResult: Equatable {
        case noLegacyData
        case missingOwner
        case prepared
        case alreadyPrepared
        case anchoredToDifferentOwner
        case invalidStoredAnchor
    }

    enum ClaimResult: Equatable {
        case noPendingClaim
        case claimed
        case differentOwner
        case invalidStoredAnchor
    }

    static let pendingOwnerKey = "stepkit_pending_legacy_owner_id"

    private let keychain: any KeychainStoring
    private let legacyData: any LegacyDataClaiming

    init(
        keychain: any KeychainStoring,
        legacyData: any LegacyDataClaiming
    ) {
        self.keychain = keychain
        self.legacyData = legacyData
    }

    /// Crea una sola vez el anclaje que autoriza una futura reclamación.
    /// Un valor existente, incluso inválido, se conserva para fallar de forma cerrada.
    func prepareClaimIfNeeded(previousOwnerID: String?) throws -> PreparationResult {
        guard try legacyData.hasUnownedLegacyData() else {
            return .noLegacyData
        }

        guard let previousOwnerID = normalized(previousOwnerID) else {
            return .missingOwner
        }

        if let storedAnchor = try keychain.getString(forKey: Self.pendingOwnerKey) {
            guard let normalizedAnchor = normalized(storedAnchor) else {
                return .invalidStoredAnchor
            }
            return normalizedAnchor == previousOwnerID
                ? .alreadyPrepared
                : .anchoredToDifferentOwner
        }

        try keychain.saveString(previousOwnerID, forKey: Self.pendingOwnerKey)
        return .prepared
    }

    /// Reclama datos solo para la identidad anclada. Si la persistencia o el borrado
    /// del marcador fallan, el marcador permanece y la operación se puede reintentar.
    func claimIfAuthorized(authenticatedOwnerID: String) throws -> ClaimResult {
        guard let storedAnchor = try keychain.getString(forKey: Self.pendingOwnerKey) else {
            return .noPendingClaim
        }
        guard let normalizedAnchor = normalized(storedAnchor) else {
            return .invalidStoredAnchor
        }
        guard let authenticatedOwnerID = normalized(authenticatedOwnerID),
              authenticatedOwnerID == normalizedAnchor else {
            return .differentOwner
        }

        try legacyData.claimLegacyData(for: authenticatedOwnerID)
        try keychain.delete(forKey: Self.pendingOwnerKey)
        return .claimed
    }

    #if DEBUG
    func resetPendingClaimForE2E() throws {
        try keychain.delete(forKey: Self.pendingOwnerKey)
    }
    #endif

    private func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
