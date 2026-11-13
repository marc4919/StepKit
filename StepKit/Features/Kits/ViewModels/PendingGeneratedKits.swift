//
//  PendingGeneratedKits.swift
//  StepKit
//

import SwiftUI
import SwiftData

/// Kits que el servidor ya ha guardado al prepararse el plan pero que la persona aún no ha
/// aceptado ni descartado. Si la app se cierra en la revisión, se descartan al volver para que
/// no cuenten como Kits activos en el plan gratuito.
enum PendingGeneratedKits {
    private static let key = "pendingGeneratedKitIDs"

    static var all: [UUID] {
        (UserDefaults.standard.stringArray(forKey: key) ?? []).compactMap(UUID.init(uuidString:))
    }

    static func add(_ id: UUID) {
        var ids = Set(all); ids.insert(id); save(ids)
    }

    static func remove(_ id: UUID) {
        var ids = Set(all); ids.remove(id); save(ids)
    }

    private static func save(_ ids: Set<UUID>) {
        UserDefaults.standard.set(ids.map(\.uuidString), forKey: key)
    }

    /// Descarta en el servidor los planes que quedaron sin aceptar (los ya guardados aquí se respetan).
    @MainActor
    static func discardLeftovers(ownerID: String, in context: ModelContext) -> Bool {
        guard !ownerID.isEmpty else { return false }
        var changed = false
        for id in all {
            let existing = try? context.fetch(FetchDescriptor<GoalEntity>(predicate: #Predicate { $0.id == id })).first
            if existing != nil { remove(id); continue }
            KitCreatorViewModel.discardOnServer(id, ownerID: ownerID, in: context)
            changed = true
        }
        return changed
    }
}
