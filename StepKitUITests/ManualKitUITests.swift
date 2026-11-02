//
//  ManualKitUITests.swift
//  StepKitUITests
//

import XCTest

/// Crear un Kit a mano con datos de diseño (sin servidor), con una auditoría de accesibilidad en cada pantalla.
final class ManualKitUITests: XCTestCase {
    @MainActor
    func testCreatingKitByHandIsAccessible() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-StepKitDesignFixtures", "kits", "-AppleLanguages", "(es)", "-kitsHomeFocusLayout", "YES"]
        app.launch()

        let create = app.buttons["kit.create"].firstMatch
        XCTAssertTrue(create.waitForExistence(timeout: 10))
        create.press(forDuration: 1)
        let fromScratch = app.buttons["Empezar de cero"].firstMatch
        XCTAssertTrue(fromScratch.waitForExistence(timeout: 5))
        fromScratch.tap()

        let name = app.textFields["manualKit.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.typeText("Hacer pan")
        XCTAssertFalse(app.buttons["manualKit.create"].isEnabled)
        audit(app, screen: "Nuevo Kit")
        app.buttons["kitCreator.today"].tap()
        XCTAssertTrue(app.buttons["manualKit.create"].isEnabled)
        app.buttons["manualKit.create"].tap()

        let firstStep = app.buttons["kit.firstStep"]
        XCTAssertTrue(firstStep.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["kit.askSteps"].exists)
        audit(app, screen: "Plan vacío")
        firstStep.tap()

        let save = app.buttons["stepDraft.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        app.typeText("Amasar")
        audit(app, screen: "Nuevo paso")
        save.tap()

        let addStep = app.buttons["kit.addStep"]
        XCTAssertTrue(addStep.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["step.row"].firstMatch.waitForExistence(timeout: 5))
        audit(app, screen: "Plan con pasos")

        app.buttons["kit.more"].tap()
        let editSteps = app.buttons["kit.editSteps"]
        XCTAssertTrue(editSteps.waitForExistence(timeout: 5))
        editSteps.tap()
        XCTAssertTrue(app.buttons["stepsEditor.add"].waitForExistence(timeout: 5))
        audit(app, screen: "Editar pasos")
    }

    /// Que todo tenga nombre para VoiceOver y se pueda tocar. El texto grande se revisa a ojo: la auditoría
    /// avisa también de los botones del sistema en la barra.
    @MainActor
    private func audit(_ app: XCUIApplication, screen: String) {
        // Justo tras cambiar de pantalla la auditoría falla con «Invalid target app».
        Thread.sleep(forTimeInterval: 1)
        do {
            try app.performAccessibilityAudit(for: [.sufficientElementDescription, .hitRegion]) { issue in
                print("AUDIT[\(screen)] \(issue.compactDescription): \(issue.element?.debugDescription.prefix(160) ?? "")")
                return false
            }
        } catch {
            XCTFail("Auditoría de \(screen): \(error)")
        }
    }
}
