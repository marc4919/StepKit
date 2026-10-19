import Foundation
import SwiftData
import Testing
@testable import StepKit

@Suite("Progress log, step block and result sync", .serialized)
@MainActor
struct ProgressContinuitySyncTests {
    private let base = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("Local entries, blocks and result confirmation are sent; server entries are applied")
    func roundTrip() async throws {
        let persistence = PersistenceController(inMemory: true)
        let context = persistence.container.mainContext

        let kit = GoalEntity(ownerID: "account-a", planTitle: "Kit", horizonDays: 30, kpi: "KPI", updatedAt: base)
        kit.resultConfirmedAt = base
        let step = StepEntity(ownerID: "account-a", stepTitle: "Paso", descriptionShort: "", descriptionLong: "",
                              estimateMinutes: 20, updatedAt: base)
        step.goal = kit
        step.blockedReason = "Falta el permiso"
        step.blockedAt = base
        let local = ProgressEntryEntity(ownerID: "account-a", kitID: kit.id, stepID: step.id, kind: .progress,
                                        note: "Dos imágenes listas", notedAt: base, updatedAt: base)
        let foreign = ProgressEntryEntity(ownerID: "account-b", kitID: UUID(), stepID: nil, kind: .progress,
                                          note: "De otra cuenta", updatedAt: base)
        let removedOnServer = ProgressEntryEntity(ownerID: "account-a", kitID: kit.id, stepID: nil, kind: .blocked,
                                                  note: "Borrada en otro dispositivo", updatedAt: base)
        context.insert(kit)
        context.insert(step)
        context.insert(local)
        context.insert(foreign)
        context.insert(removedOnServer)
        try context.save()

        let remoteID = UUID()
        let later = base.addingTimeInterval(30)
        let response = SyncBatchResponse(
            kits: [],
            steps: [],
            progressEntries: [
                ProgressEntrySyncDTO(id: remoteID, kitId: kit.id, stepId: step.id, kind: "blocked",
                                     note: "Esperando respuesta", notedAt: later, createdAt: later,
                                     updatedAt: later, deletedAt: nil),
                ProgressEntrySyncDTO(id: removedOnServer.id, kitId: kit.id, stepId: nil, kind: "blocked",
                                     note: removedOnServer.note, notedAt: base, createdAt: base,
                                     updatedAt: later, deletedAt: later),
            ],
            conflicts: []
        )
        let network = CapturingSyncNetwork(response: response)
        let preferencesName = "StepKitTests.Continuity.\(UUID().uuidString)"
        let preferences = try #require(UserDefaults(suiteName: preferencesName))
        defer { preferences.removePersistentDomain(forName: preferencesName) }
        let service = SyncService(
            authManager: makeAuthenticatedManager(),
            networkService: network,
            preferences: preferences,
            now: { later.addingTimeInterval(60) }
        )
        service.configure(with: context)

        try await service.syncAll()

        let request = try #require(network.lastRequest)
        #expect(request.progressEntries.map(\.id).contains(local.id))
        #expect(!request.progressEntries.map(\.id).contains(foreign.id))
        #expect(request.steps.first?.blockedReason == "Falta el permiso")
        #expect(request.kits.first?.resultConfirmedAt != nil)

        let entries = try context.fetch(FetchDescriptor<ProgressEntryEntity>())
        let remote = try #require(entries.first { $0.id == remoteID })
        #expect(remote.kind == .blocked)
        #expect(remote.note == "Esperando respuesta")
        #expect(remote.ownerID == "account-a")
        #expect(!entries.contains { $0.id == removedOnServer.id })
        #expect(entries.contains { $0.id == local.id })
    }

    private func makeAuthenticatedManager() -> AuthManager {
        let manager = AuthManager(keychain: ContinuityKeychainStore())
        manager.saveAuth(
            token: "token-account-a",
            user: UserInfo(id: "account-a", tier: "premium", monthlyTokensUsed: 0, monthlyTokenQuota: 10_000)
        )
        return manager
    }
}

@MainActor
private final class CapturingSyncNetwork: SyncNetworkServicing {
    private let response: SyncBatchResponse
    private(set) var lastRequest: SyncBatchRequest?

    init(response: SyncBatchResponse) {
        self.response = response
    }

    func syncBatch(_ request: SyncBatchRequest, token: String) async throws -> SyncBatchResponse {
        lastRequest = request
        return response
    }
}

@MainActor
private final class ContinuityKeychainStore: KeychainStoring {
    private var values: [String: Data] = [:]

    func save<T: Codable>(_ value: T, forKey key: String) throws {
        values[key] = try JSONEncoder().encode(value)
    }

    func get<T: Codable>(forKey key: String) throws -> T? {
        guard let data = values[key] else { return nil }
        return try JSONDecoder().decode(T.self, from: data)
    }

    func saveString(_ value: String, forKey key: String) throws {
        values[key] = Data(value.utf8)
    }

    func getString(forKey key: String) throws -> String? {
        guard let data = values[key] else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func delete(forKey key: String) throws {
        values.removeValue(forKey: key)
    }
}
