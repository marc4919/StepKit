//
//  AccountDeletionTests.swift
//  StepKitTests
//

import Foundation
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

@MainActor
struct SupportContactTests {
    @Test func theCodeTravelsInTheSubjectOfTheEmail() throws {
        let url = try #require(AboutView.contactURL(supportCode: "SK-7F3K-92QX"))
        #expect(url.scheme == "mailto")
        #expect(url.absoluteString.hasPrefix("mailto:marcgt.dev@icloud.com?subject="))
        #expect(url.absoluteString.contains("SK-7F3K-92QX"))
    }

    @Test func withoutACodeTheEmailHasNoSubject() {
        #expect(AboutView.contactURL(supportCode: nil)?.absoluteString == "mailto:marcgt.dev@icloud.com")
    }

    /// El servidor actual todavía no envía el código: el perfil se sigue leyendo igual.
    @Test func aProfileWithoutACodeStillDecodes() throws {
        let json = """
        {"id":"7B4C9F70-2C8E-4B7A-9A1D-3E1F0C5D2A11","tier":"free","limits":{"monthlyTokensUsed":0,"monthlyTokenQuota":10,"maxActiveGoalsFree":2,"monthlyAICalls":0,"monthlyAICallsQuota":10,"activeKitsCount":0}}
        """
        let profile = try JSONDecoder().decode(UserProfileResponse.self, from: Data(json.utf8))
        #expect(profile.supportCode == nil)
        #expect(UserInfo(from: profile).supportCode == nil)
    }
}
