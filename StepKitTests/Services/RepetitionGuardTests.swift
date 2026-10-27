//
//  RepetitionGuardTests.swift
//  StepKitTests
//

import Testing
@testable import StepKit

@Suite("RepetitionGuard")
struct RepetitionGuardTests {
    @Test("Cuts a run of repeated punctuation")
    func cutsPunctuationRun() {
        let text = "Hola, Marc. Celebro tu esfuerzo inicial, ¡¡¡¡¡¡¡¡¡¡¡¡¡¡"
        #expect(RepetitionGuard.cut(text) == "Hola, Marc. Celebro tu esfuerzo inicial.")
    }

    @Test("Cuts a short phrase repeated three times")
    func cutsRepeatedPhrase() {
        let text = "Empieza hoy. vamos allá vamos allá vamos allá "
        #expect(RepetitionGuard.cut(text) == "Empieza hoy. vamos allá.")
    }

    @Test("Leaves a normal reply alone")
    func keepsNormalText() {
        #expect(RepetitionGuard.cut("¡Hola! Tu próximo paso es «Tostar los piñones», unos 5 minutos.") == nil)
        #expect(RepetitionGuard.cut("Perfecto... seguimos.") == nil)
    }
}
