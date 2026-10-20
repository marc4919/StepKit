import XCTest

/// Asistente del Kit con datos de diseño (sin servidor): la propuesta se acepta entera.
final class KitAssistantUITests: XCTestCase {
    @MainActor
    func testProposalFromStepIsAcceptedAsAWhole() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-StepKitDesignFixtures", "assistantProposal"]
        app.launch()

        let accept = app.buttons["proposal.accept"]
        XCTAssertTrue(accept.waitForExistence(timeout: 10))
        // Las fechas de los datos de diseño son relativas a hoy.
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Mover el paso 3 al")).firstMatch.exists)
        accept.tap()
        XCTAssertTrue(app.staticTexts["Aplicada"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["proposal.discard"].exists)
    }
}
