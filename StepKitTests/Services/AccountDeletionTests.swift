//
//  AccountDeletionTests.swift
//  StepKitTests
//

import Testing
@testable import StepKit

@MainActor
struct AccountDeletionTests {
    @Test func onlyA2xxConfirmsTheDeletion() throws {
        try AccountDeletionService.requireDeleted(status: 200)
        try AccountDeletionService.requireDeleted(status: 204)
    }

    /// Un 401 también es una sesión caducada, con los datos aún en el servidor: nunca se da por borrada.
    @Test func expiredSessionIsNotADeletion() {
        #expect(throws: AccountDeletionService.Failure.self) {
            try AccountDeletionService.requireDeleted(status: 401)
        }
        do {
            try AccountDeletionService.requireDeleted(status: 401)
        } catch AccountDeletionService.Failure.sessionExpired {
            return
        } catch {
            Issue.record("Se esperaba sessionExpired: \(error)")
        }
    }

    @Test func otherAnswersAreNotADeletion() {
        for status in [0, 403, 500] {
            #expect(throws: AccountDeletionService.Failure.self) {
                try AccountDeletionService.requireDeleted(status: status)
            }
        }
    }
}

@MainActor
struct SerialTaskQueueTests {
    /// Una pasada que empieza después no se mezcla con la anterior, aunque la anterior tarde más.
    @Test func workRunsOneAtATimeInOrder() async {
        var queue = SerialTaskQueue()
        var events: [String] = []
        queue.enqueue {
            events.append("older start")
            try? await Task.sleep(for: .milliseconds(100))
            events.append("older end")
        }
        await queue.enqueue {
            events.append("newer")
        }.value
        #expect(events == ["older start", "older end", "newer"])
    }
}
