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
        create.tap()
        // «A mano» se elige en la barra de «Nuevo Kit»; el formulario es el mismo.
        let byHand = app.segmentedControls["kitCreator.mode"].buttons["A mano"]
        XCTAssertTrue(byHand.waitForExistence(timeout: 5))
        byHand.tap()

        let name = app.descendants(matching: .any)["kitCreator.description"].firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Hacer pan")
        XCTAssertFalse(app.buttons["kitCreator.create"].isEnabled)
        audit(app, screen: "Nuevo Kit")
        app.buttons["kitCreator.today"].tap()
        XCTAssertTrue(app.buttons["kitCreator.create"].isEnabled)
        XCTAssertEqual(app.buttons["kitCreator.create"].label, "Crear Kit")
        app.buttons["kitCreator.create"].tap()

        let firstStep = app.buttons["kit.firstStep"]
        XCTAssertTrue(firstStep.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["kit.askSteps"].exists)
        audit(app, screen: "Plan vacío")
        firstStep.tap()

        let save = app.buttons["stepDraft.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        app.typeText("Amasar")
        audit(app, screen: "Nuevo paso")
        app.switches["stepDraft.dateToggle"].switches.firstMatch.tap()
        // El Kit acaba hoy: con un solo día posible no hay atajos.
        XCTAssertTrue(app.datePickers["stepDraft.date"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["stepDate.today"].exists)
        audit(app, screen: "Nuevo paso con fecha")
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

    /// Con una fecha final lejana hay atajos para los pasos, y la fecha final se puede cambiar en Editar Kit.
    @MainActor
    func testStepShortcutsAndFinalDate() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-StepKitDesignFixtures", "kits", "-AppleLanguages", "(es)", "-kitsHomeFocusLayout", "YES"]
        app.launch()

        let create = app.buttons["kit.create"].firstMatch
        XCTAssertTrue(create.waitForExistence(timeout: 10))
        create.tap()
        // «A mano» se elige en la barra de «Nuevo Kit»; el formulario es el mismo.
        let byHand = app.segmentedControls["kitCreator.mode"].buttons["A mano"]
        XCTAssertTrue(byHand.waitForExistence(timeout: 5))
        byHand.tap()

        let name = app.descendants(matching: .any)["kitCreator.description"].firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Hacer pan")
        app.buttons["1 mes"].tap()
        app.buttons["kitCreator.create"].tap()

        let firstStep = app.buttons["kit.firstStep"]
        XCTAssertTrue(firstStep.waitForExistence(timeout: 5))
        firstStep.tap()
        XCTAssertTrue(app.buttons["stepDraft.save"].waitForExistence(timeout: 5))
        app.typeText("Amasar")
        app.switches["stepDraft.dateToggle"].switches.firstMatch.tap()
        let tomorrow = app.buttons["stepDate.tomorrow"]
        XCTAssertTrue(tomorrow.waitForExistence(timeout: 5))
        tomorrow.tap()
        XCTAssertTrue(tomorrow.isSelected)
        app.buttons["stepDraft.save"].tap()

        let more = app.buttons["kit.more"]
        XCTAssertTrue(more.waitForExistence(timeout: 5))
        more.tap()
        let info = app.buttons["kit.info"]
        XCTAssertTrue(info.waitForExistence(timeout: 5))
        info.tap()
        let edit = app.buttons["kit.edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        edit.tap()
        // Sin indicador también se puede editar: el Kit se creó a mano.
        XCTAssertTrue(app.datePickers["kitEdit.finalDate"].waitForExistence(timeout: 5))
        audit(app, screen: "Editar Kit")
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
