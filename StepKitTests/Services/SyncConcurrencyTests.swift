import Foundation
import SwiftData
import Testing
@testable import StepKit

@Suite("Client sync concurrency", .serialized)
@MainActor
struct SyncConcurrencyTests {
    @Test("A suspended request preserves later edits and drains a second batch")
    func suspendedRequestPreservesLaterEditAndDrains() async throws {
        let initialDate = Date(timeIntervalSince1970: 1_700_000_000)
        let firstCutoff = initialDate.addingTimeInterval(10)
        let localEditDate = initialDate.addingTimeInterval(20)
        let secondCutoff = initialDate.addingTimeInterval(30)

        let persistence = PersistenceController(inMemory: true)
        let context = persistence.container.mainContext
        let goal = GoalEntity(
            ownerID: "account-a",
            planTitle: "Local kit",
            horizonDays: 30,
            kpi: "Complete",
            updatedAt: initialDate
        )
        let step = StepEntity(
            ownerID: "account-a",
            stepTitle: "Local step",
            descriptionShort: "Short",
            descriptionLong: "Long",
            estimateMinutes: 15,
            order: 0,
            isCompleted: false,
            createdAt: initialDate,
            updatedAt: initialDate
        )
        step.goal = goal

        // Ya existe antes del request, pero su reloj es posterior al primer
        // cutoff. No forma parte de un batch cuyo cursor no puede cubrirlo.
        let futureDatedGoal = GoalEntity(
            ownerID: "account-a",
            planTitle: "Future dated kit",
            horizonDays: 7,
            kpi: "Wait",
            updatedAt: localEditDate
        )
        context.insert(goal)
        context.insert(step)
        context.insert(futureDatedGoal)
        try context.save()

        let network = SuspendedSyncNetworkService()
        let dates = SyncDateSequence([firstCutoff, secondCutoff])
        let preferencesName = "StepKitTests.SyncConcurrency.\(UUID().uuidString)"
        let preferences = try #require(UserDefaults(suiteName: preferencesName))
        defer { preferences.removePersistentDomain(forName: preferencesName) }

        let authManager = makeAuthenticatedManager(userID: "account-a")
        let service = SyncService(
            authManager: authManager,
            networkService: network,
            preferences: preferences,
            now: { dates.next() }
        )
        service.configure(with: context)
        let manager = SyncManager(syncService: service)

        var firstForceReturned = false
        let firstForce = Task { @MainActor in
            await manager.forceSync()
            firstForceReturned = true
        }
        await network.waitForRequestCount(1)

        let firstRequest = try #require(network.requests.first)
        #expect(firstRequest.kits.map(\.id).contains(goal.id))
        #expect(!firstRequest.kits.map(\.id).contains(futureDatedGoal.id))
        #expect(firstRequest.steps.map(\.id).contains(step.id))
        #expect(manager.isSyncing)

        // Simula la edición de UI mientras el primer request está suspendido.
        step.isCompleted = true
        step.updatedAt = localEditDate
        goal.progress = 1
        goal.updatedAt = localEditDate
        try context.save()

        var secondForceReturned = false
        let secondForce = Task { @MainActor in
            await manager.forceSync()
            secondForceReturned = true
        }

        #expect(!firstForceReturned)
        #expect(!secondForceReturned)

        // El primer snapshot representa el estado anterior a la edición local.
        network.resumeRequest(
            at: 0,
            with: SyncBatchResponse(
                kits: [kitDTO(from: goal, updatedAt: initialDate, progress: 0)],
                steps: [stepDTO(from: step, updatedAt: initialDate, completed: false)],
                conflicts: []
            )
        )

        await network.waitForRequestCount(2)

        // El cursor del primer request se mantiene en su cutoff mientras el
        // segundo está suspendido, y la operación completa sigue observable.
        #expect(service.lastSyncDate == firstCutoff)
        #expect(manager.isSyncing)
        #expect(!firstForceReturned)
        #expect(!secondForceReturned)
        #expect(step.isCompleted)
        #expect(step.updatedAt == localEditDate)
        #expect(goal.updatedAt == localEditDate)

        let secondRequest = network.requests[1]
        let secondStep = try #require(secondRequest.steps.first { $0.id == step.id })
        #expect(secondStep.completed)
        #expect(secondStep.updatedAt == localEditDate)
        #expect(secondRequest.kits.map(\.id).contains(goal.id))
        #expect(secondRequest.kits.map(\.id).contains(futureDatedGoal.id))

        network.resumeRequest(
            at: 1,
            with: SyncBatchResponse(kits: [], steps: [], conflicts: [])
        )
        await firstForce.value
        await secondForce.value

        #expect(firstForceReturned)
        #expect(secondForceReturned)
        #expect(!manager.isSyncing)
        #expect(manager.completedSyncCount == 2)
        #expect(service.lastSyncDate == secondCutoff)
        #expect(step.isCompleted)
    }

    @Test("A suspended response is rejected after switching accounts")
    func suspendedResponseIsRejectedAfterAccountSwitch() async throws {
        let initialDate = Date(timeIntervalSince1970: 1_700_100_000)
        let accountACutoff = initialDate.addingTimeInterval(10)
        let accountBCutoff = initialDate.addingTimeInterval(20)
        let persistence = PersistenceController(inMemory: true)
        let context = persistence.container.mainContext
        let goalA = GoalEntity(
            ownerID: "account-a",
            planTitle: "Account A local value",
            horizonDays: 30,
            kpi: "Complete",
            updatedAt: initialDate
        )
        let goalB = GoalEntity(
            ownerID: "account-b",
            planTitle: "Account B local value",
            horizonDays: 14,
            kpi: "Complete",
            updatedAt: initialDate
        )
        context.insert(goalA)
        context.insert(goalB)
        try context.save()

        let network = SuspendedSyncNetworkService()
        let dates = SyncDateSequence([accountACutoff, accountBCutoff])
        let preferencesName = "StepKitTests.SyncAccountSwitch.\(UUID().uuidString)"
        let preferences = try #require(UserDefaults(suiteName: preferencesName))
        defer { preferences.removePersistentDomain(forName: preferencesName) }

        let authManager = makeAuthenticatedManager(userID: "account-a")
        let service = SyncService(
            authManager: authManager,
            networkService: network,
            preferences: preferences,
            now: { dates.next() }
        )
        service.configure(with: context)
        let manager = SyncManager(syncService: service)

        let accountASync = Task { @MainActor in await manager.forceSync() }
        await network.waitForRequestCount(1)
        #expect(network.requests[0].kits.compactMap(\.id) == [goalA.id])

        authManager.saveAuth(
            token: "token-account-b",
            user: makeUser(id: "account-b")
        )
        manager.stopAutoSync()
        network.resumeRequest(
            at: 0,
            with: SyncBatchResponse(
                kits: [kitDTO(
                    from: goalA,
                    updatedAt: accountACutoff,
                    progress: 0,
                    title: "Stale remote A value"
                )],
                steps: [],
                conflicts: []
            )
        )
        await accountASync.value

        #expect(goalA.planTitle == "Account A local value")
        #expect(service.lastSyncDate == nil, "B must not inherit A's cutoff")
        #expect(!manager.isSyncing)
        #expect(manager.completedSyncCount == 0)

        let accountBSync = Task { @MainActor in await manager.forceSync() }
        await network.waitForRequestCount(2)
        #expect(network.requests[1].kits.compactMap(\.id) == [goalB.id])
        #expect(!network.requests[1].kits.compactMap(\.id).contains(goalA.id))
        network.resumeRequest(
            at: 1,
            with: SyncBatchResponse(kits: [], steps: [], conflicts: [])
        )
        await accountBSync.value

        #expect(service.lastSyncDate == accountBCutoff)
        #expect(manager.completedSyncCount == 1)

        authManager.saveAuth(
            token: "token-account-a-2",
            user: makeUser(id: "account-a")
        )
        #expect(service.lastSyncDate == nil, "Rejected A response must not advance A")
    }

    private func makeAuthenticatedManager(userID: String) -> AuthManager {
        let manager = AuthManager(keychain: SyncTestKeychainStore())
        manager.saveAuth(
            token: "token-\(userID)",
            user: makeUser(id: userID)
        )
        return manager
    }

    private func makeUser(id: String) -> UserInfo {
        UserInfo(
            id: id,
            tier: "premium",
            monthlyTokensUsed: 0,
            monthlyTokenQuota: 10_000
        )
    }

    private func kitDTO(
        from goal: GoalEntity,
        updatedAt: Date,
        progress: Double,
        title: String? = nil
    ) -> KitSyncDTO {
        KitSyncDTO(
            id: goal.id,
            title: title ?? goal.planTitle,
            kpi: goal.kpi,
            horizonDays: goal.horizonDays,
            metaType: goal.metaType,
            metaTags: goal.metaTags,
            risks: goal.risks,
            version: goal.version,
            progress: progress,
            sourceModel: goal.sourceModel,
            promptVersion: nil,
            createdAt: goal.createdAt,
            updatedAt: updatedAt,
            deletedAt: nil,
            deleted: false,
            steps: nil
        )
    }

    private func stepDTO(
        from step: StepEntity,
        updatedAt: Date,
        completed: Bool
    ) -> StepSyncDTO {
        StepSyncDTO(
            id: step.id,
            kitId: step.goal?.id ?? UUID(),
            title: step.stepTitle,
            descriptionShort: step.descriptionShort,
            descriptionLong: step.descriptionLong,
            estimateMinutes: step.estimateMinutes,
            suggestedDeadline: step.suggestedDeadline,
            effortLevel: step.effortLevel,
            adaptsTo: step.adaptsTo,
            blockedByPremium: step.blockedByPremium,
            order: step.order,
            completed: completed,
            createdAt: step.createdAt,
            updatedAt: updatedAt,
            deletedAt: nil
        )
    }
}

@MainActor
private final class SuspendedSyncNetworkService: SyncNetworkServicing {
    private(set) var requests: [SyncBatchRequest] = []
    private var responseContinuations: [Int: CheckedContinuation<SyncBatchResponse, Never>] = [:]
    private var requestWaiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []

    func syncBatch(_ request: SyncBatchRequest, token: String) async throws -> SyncBatchResponse {
        let index = requests.count
        requests.append(request)

        let readyWaiters = requestWaiters.filter { requests.count >= $0.count }
        requestWaiters.removeAll { requests.count >= $0.count }
        readyWaiters.forEach { $0.continuation.resume() }

        return await withCheckedContinuation { continuation in
            responseContinuations[index] = continuation
        }
    }

    func waitForRequestCount(_ count: Int) async {
        guard requests.count < count else { return }
        await withCheckedContinuation { continuation in
            requestWaiters.append((count, continuation))
        }
    }

    func resumeRequest(at index: Int, with response: SyncBatchResponse) {
        guard let continuation = responseContinuations.removeValue(forKey: index) else {
            Issue.record("No suspended sync request exists at index \(index)")
            return
        }
        continuation.resume(returning: response)
    }
}

@MainActor
private final class SyncDateSequence {
    private var dates: [Date]

    init(_ dates: [Date]) {
        self.dates = dates
    }

    func next() -> Date {
        guard !dates.isEmpty else {
            Issue.record("Sync requested more cutoff dates than expected")
            return .distantFuture
        }
        return dates.removeFirst()
    }
}

@MainActor
private final class SyncTestKeychainStore: KeychainStoring {
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
