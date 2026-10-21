//
//  StepKitUITests.swift
//  StepKitUITests
//
//  Functional acceptance journey for GOAL-003.
//

import XCTest

final class StepKitUITests: XCTestCase {
    private struct SyncCheckpoint {
        let cursor: String
        let completedCount: Int
    }

    private enum Account {
        static let a = "account-a"
        static let b = "account-b"
    }

    private enum Identifier {
        static let appState = "e2e.appState"
        static let onboardingAction = "onboarding.action"
        static let consentAccept = "consent.accept"
        static let consentContinue = "consent.continue"
        static let emptyStateAction = "emptyState.primaryAction"
        static let createKit = "kit.create"
        static let kitRow = "kit.row"
        static let kitDescription = "kitCreator.description"
        static let submitKit = "kitCreator.create"
        static let saveKit = "kitCreator.save"
        static let stepRow = "step.row"
        static let kitInfo = "kit.info"
        static let kitInfoClose = "kitInfo.close"
        static let editKit = "kit.edit"
        static let kitEditTitle = "kitEdit.title"
        static let kitEditKPI = "kitEdit.kpi"
        static let kitEditSave = "kitEdit.save"
        static let editStep = "step.edit"
        static let stepEditTitle = "stepEdit.title"
        static let stepEditShortDescription = "stepEdit.shortDescription"
        static let stepEditSave = "stepEdit.save"
        static let toggleCompletion = "step.toggleCompletion"
        static let confirmDelete = "delete.confirm"
        static let signOut = "profile.signOut"
        static let signInWithApple = "auth.signInWithApple"
    }

    private let originalFixtureTitle = "Plan E2E estable"
    private let editedFixtureTitle = "Plan E2E editado"
    private let editedFixtureKPI = "Validación E2E sincronizada"
    private let originalFirstStep = "Preparar el entorno de prueba"
    private let editedFirstStep = "Preparar el entorno editado"
    private let editedFirstStepDescription = "Entorno validado y listo para continuar"
    private let defaultTimeout: TimeInterval = 15
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        if app?.state != .notRunning {
            app?.terminate()
        }
        app = nil
    }

    /// Un único recorrido secuencial evita que cuentas y estado remoto compartidos
    /// se ejecuten en paralelo. El prólogo y el epílogo limpian ambas cuentas para
    /// que exactamente el mismo test pueda pasar dos veces seguidas.
    @MainActor
    func testGoal003CriticalJourney() throws {
        // Prólogo: las dos identidades fijas empiezan sin datos remotos residuales.
        launch(account: Account.a, resetLocalState: true)
        completeOnboardingAndConsentIfNeeded()
        waitForHomeAndInitialSync()
        let ownerA = currentOwnerID()
        XCTAssertNotEqual(ownerA, "none")
        deleteAllVisibleKits()

        launch(account: Account.b)
        waitForHomeAndInitialSync()
        let ownerB = currentOwnerID()
        XCTAssertNotEqual(ownerB, "none")
        XCTAssertNotEqual(ownerA, ownerB, "Las cuentas E2E deben resolver usuarios distintos")
        deleteAllVisibleKits()

        // Login A, creación determinista, edición real de Kit y Step y completado.
        launch(account: Account.a)
        waitForHomeAndInitialSync()
        XCTAssertEqual(currentOwnerID(), ownerA)
        XCTAssertEqual(kitRows.count, 0)

        let creationCheckpoint = createFixtureKit()
        waitForSyncAdvance(from: creationCheckpoint, operation: "crear el Kit")
        XCTAssertEqual(stepRows.count, 3)
        attachScreenshot(named: "GOAL-003-A-Kit-created")

        let kitEditCheckpoint = editFixtureKit()
        waitForSyncAdvance(from: kitEditCheckpoint, operation: "editar el Kit")
        attachScreenshot(named: "GOAL-003-A-Kit-edited")

        let firstStep = stepRows
            .matching(NSPredicate(format: "label CONTAINS %@", originalFirstStep))
            .firstMatch
        XCTAssertTrue(firstStep.waitForExistence(timeout: defaultTimeout))
        firstStep.tap()

        let stepEditCheckpoint = editFirstStep()
        waitForSyncAdvance(from: stepEditCheckpoint, operation: "editar el paso")
        attachScreenshot(named: "GOAL-003-A-Step-edited")

        let completionButton = element(Identifier.toggleCompletion)
        XCTAssertTrue(completionButton.waitForExistence(timeout: defaultTimeout))
        XCTAssertEqual(completionButton.label, "Marcar como completado")
        let completionCheckpoint = currentSyncCheckpoint()
        completionButton.tap()
        XCTAssertTrue(waitUntil(timeout: defaultTimeout) {
            completionButton.label == "Marcar como pendiente"
        })
        waitForSyncAdvance(from: completionCheckpoint, operation: "completar el paso")
        attachScreenshot(named: "GOAL-003-A-Step-completed")

        // Relanzamiento ordinario: usa el JWT almacenado y el GET /me normal.
        launchStoredSession()
        waitForHomeAndInitialSync()
        XCTAssertEqual(currentOwnerID(), ownerA)
        assertFixtureKitCount(1, title: editedFixtureTitle)
        assertFirstStepIsCompleted()

        // Segundo cliente lógico: borra todo lo local y rehidrata desde servidor.
        launch(account: Account.a, resetLocalState: true)
        completeOnboardingAndConsentIfNeeded()
        waitForHomeAndInitialSync()
        XCTAssertEqual(currentOwnerID(), ownerA)
        assertFixtureKitCount(1, title: editedFixtureTitle)
        assertFirstStepIsCompleted()
        attachScreenshot(named: "GOAL-003-A-Remote-rehydration")

        // Logout real de A y login B: B no puede ver el Kit de A.
        signOutFromProfile()
        XCTAssertTrue(element(Identifier.signInWithApple).waitForExistence(timeout: defaultTimeout))
        launch(account: Account.b)
        waitForHomeAndInitialSync()
        XCTAssertEqual(currentOwnerID(), ownerB)
        XCTAssertEqual(kitRows.count, 0, "B no debe ver datos de A")

        let bCreationCheckpoint = createFixtureKit()
        waitForSyncAdvance(from: bCreationCheckpoint, operation: "crear el Kit de B")

        // Volver a A: el mismo título existe en B, por lo que count == 1 prueba
        // que la lista no mezcla ambos propietarios. El de A conserva su edición.
        launch(account: Account.a)
        waitForHomeAndInitialSync()
        XCTAssertEqual(currentOwnerID(), ownerA)
        assertFixtureKitCount(1, title: editedFixtureTitle)
        assertFirstStepIsCompleted()
        attachScreenshot(named: "GOAL-003-Account-isolation")

        // Borrado A + sync + reset local: el tombstone remoto impide resurrección.
        returnToKitsRoot()
        let deleteCheckpoint = currentSyncCheckpoint()
        deleteFirstVisibleKit()
        waitForSyncAdvance(from: deleteCheckpoint, operation: "eliminar el Kit de A")

        launch(account: Account.a, resetLocalState: true)
        completeOnboardingAndConsentIfNeeded()
        waitForHomeAndInitialSync()
        XCTAssertEqual(kitRows.count, 0, "El Kit eliminado no debe resucitar tras rehidratar")
        attachScreenshot(named: "GOAL-003-A-Remote-delete")

        // B continúa intacta pese al borrado de A; se limpia al terminar para que
        // una segunda ejecución empiece desde el mismo estado remoto.
        launch(account: Account.b)
        waitForHomeAndInitialSync()
        XCTAssertEqual(currentOwnerID(), ownerB)
        assertFixtureKitCount(1, title: originalFixtureTitle)
        let bCleanupCheckpoint = currentSyncCheckpoint()
        deleteFirstVisibleKit()
        waitForSyncAdvance(from: bCleanupCheckpoint, operation: "limpiar el Kit de B")

        launch(account: Account.b, resetLocalState: true)
        completeOnboardingAndConsentIfNeeded()
        waitForHomeAndInitialSync()
        XCTAssertEqual(kitRows.count, 0, "La limpieza remota de B debe quedar confirmada")

        // Sesión persistida inválida: pasa por restauración normal y falla cerrada.
        launchInvalidStoredSession(resetLocalState: true)
        completeOnboardingAndConsentIfNeeded()
        let appleSignIn = element(Identifier.signInWithApple)
        XCTAssertTrue(appleSignIn.waitForExistence(timeout: defaultTimeout))
        XCTAssertFalse(element(Identifier.appState).exists, "Una sesión inválida no debe mostrar contenido privado")
        attachScreenshot(named: "GOAL-003-Invalid-session-fail-closed")
    }

    // MARK: - Launching

    @MainActor
    private func launch(account: String, resetLocalState: Bool = false) {
        launch(arguments: {
            var arguments = ["-StepKitE2EAccount", account]
            if resetLocalState {
                arguments.append("-StepKitE2EResetLocalState")
            }
            return arguments
        }())
    }

    @MainActor
    private func launchStoredSession() {
        launch(arguments: [])
    }

    @MainActor
    private func launchInvalidStoredSession(resetLocalState: Bool) {
        var arguments = ["-StepKitE2EInvalidStoredSession"]
        if resetLocalState {
            arguments.append("-StepKitE2EResetLocalState")
        }
        launch(arguments: arguments)
    }

    @MainActor
    private func launch(arguments: [String]) {
        if app?.state != .notRunning {
            app?.terminate()
        }

        let application = XCUIApplication()
        let baseURL = ProcessInfo.processInfo.environment["STEPKIT_E2E_BASE_URL"]
            ?? "http://127.0.0.1:8080"
        application.launchArguments = [
            "-StepKitAPIBaseURL", baseURL,
            "-StepKitE2ESuppressNotifications",
        ] + arguments
        application.launch()
        app = application
    }

    // MARK: - Onboarding and navigation

    @MainActor
    private func completeOnboardingAndConsentIfNeeded() {
        // v4.4: la bienvenida no pide permisos; el de IA se pide al crear el primer Kit.
        let action = element(Identifier.onboardingAction)
        guard action.waitForExistence(timeout: 3) else { return }

        XCTAssertTrue(app.staticTexts["Un objetivo grande.\nUn primer paso claro."].exists)
        // Las páginas vecinas ya están en la jerarquía: se avanza hasta ver «Empezar».
        var remainingTaps = 6
        while action.label != "Empezar", remainingTaps > 0 {
            action.tap()
            _ = waitUntil(timeout: 2) { action.label == "Empezar" }
            remainingTaps -= 1
        }
        XCTAssertEqual(action.label, "Empezar")
        action.tap()
    }

    /// Permiso explícito de IA (5.1.2(i)) justo antes del primer envío.
    @MainActor
    private func acceptAIConsentIfPresented() {
        let header = app.staticTexts["Antes de preparar tu plan"]
        guard header.waitForExistence(timeout: 5) else { return }
        // El Form carga el interruptor al desplazarse.
        let accept = element(Identifier.consentAccept)
        var remainingSwipes = 4
        while !accept.exists, remainingSwipes > 0 {
            app.swipeUp()
            remainingSwipes -= 1
        }
        XCTAssertTrue(accept.waitForExistence(timeout: defaultTimeout))
        let continueButton = element(Identifier.consentContinue)
        XCTAssertTrue(continueButton.waitForExistence(timeout: defaultTimeout))
        XCTAssertFalse(continueButton.isEnabled)
        scrollUpUntilHittable(accept)
        accept.switches.firstMatch.exists ? accept.switches.firstMatch.tap() : accept.tap()
        XCTAssertTrue(waitUntil(timeout: defaultTimeout) {
            self.element(Identifier.consentContinue).isEnabled
        })
        element(Identifier.consentContinue).tap()
    }

    @MainActor
    private func waitForHomeAndInitialSync() {
        XCTAssertTrue(app.tabBars.buttons["Kits"].waitForExistence(timeout: defaultTimeout))
        let state = element(Identifier.appState)
        XCTAssertTrue(state.waitForExistence(timeout: defaultTimeout))

        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { object, _ in
            guard let element = object as? XCUIElement,
                  let value = element.value as? String else {
                return false
            }
            return value.contains("sync=idle")
                && !value.contains("cursor=never")
                && !value.contains("completed=0")
        }, object: state)
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation], timeout: defaultTimeout),
            .completed,
            "La sincronización inicial no se confirmó: \(state.value ?? "sin valor")"
        )
    }

    @MainActor
    private func signOutFromProfile() {
        revealTabBar()
        app.tabBars.buttons["Perfil"].tap()
        let signOut = element(Identifier.signOut)
        XCTAssertTrue(signOut.waitForExistence(timeout: defaultTimeout))
        scrollUpUntilHittable(signOut)
        signOut.tap()
        let confirmation = app.alerts.buttons["Cerrar sesión"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: defaultTimeout))
        confirmation.tap()
    }

    /// v4.4 oculta la barra de pestañas dentro de un paso: se vuelve atrás hasta verla.
    @MainActor
    private func revealTabBar() {
        var remainingBackNavigation = 3
        while !app.tabBars.firstMatch.exists, remainingBackNavigation > 0 {
            let back = app.navigationBars.buttons.firstMatch
            guard back.exists else { break }
            back.tap()
            remainingBackNavigation -= 1
        }
    }

    @MainActor
    private func returnToKitsRoot() {
        revealTabBar()
        app.tabBars.buttons["Kits"].tap()
        var remainingBackNavigation = 3
        while kitRows.count == 0, remainingBackNavigation > 0 {
            let firstNavigationButton = app.navigationBars.buttons.firstMatch
            guard firstNavigationButton.exists else { break }
            firstNavigationButton.tap()
            remainingBackNavigation -= 1
        }
        XCTAssertTrue(waitUntil(timeout: defaultTimeout) { self.kitRows.count > 0 })
    }

    // MARK: - Kit actions

    @MainActor
    private func createFixtureKit() -> SyncCheckpoint {
        // El creador se presenta a pantalla completa y oculta el marcador E2E;
        // capturamos el ciclo inmediatamente antes de abrirlo.
        let checkpoint = currentSyncCheckpoint()
        let emptyAction = element(Identifier.emptyStateAction)
        if emptyAction.waitForExistence(timeout: 2) {
            emptyAction.tap()
        } else {
            let create = element(Identifier.createKit)
            XCTAssertTrue(create.waitForExistence(timeout: defaultTimeout))
            create.tap()
        }

        let description = element(Identifier.kitDescription)
        XCTAssertTrue(description.waitForExistence(timeout: defaultTimeout))
        description.tap()
        description.typeText("Recorrido funcional determinista GOAL-003")

        // v4.4: el botón está al final del Form, que carga sus filas al desplazarse.
        let submit = element(Identifier.submitKit)
        var remainingSwipes = 5
        while !submit.exists, remainingSwipes > 0 {
            app.swipeUp()
            remainingSwipes -= 1
        }
        XCTAssertTrue(submit.waitForExistence(timeout: defaultTimeout))
        scrollUpUntilHittable(submit)
        submit.tap()
        acceptAIConsentIfPresented()

        let save = element(Identifier.saveKit)
        XCTAssertTrue(save.waitForExistence(timeout: 30), "El fixture AI no terminó")
        // «Tu plan» aparece en cascada tras la transición de la esfera.
        XCTAssertTrue(app.staticTexts[originalFixtureTitle].waitForExistence(timeout: defaultTimeout))
        scrollUpUntilHittable(save)
        save.tap()
        XCTAssertTrue(stepRows.firstMatch.waitForExistence(timeout: defaultTimeout))
        return checkpoint
    }

    @MainActor
    private func editFixtureKit() -> SyncCheckpoint {
        let checkpoint = currentSyncCheckpoint()
        let info = element(Identifier.kitInfo)
        XCTAssertTrue(info.waitForExistence(timeout: defaultTimeout))
        info.tap()
        let edit = element(Identifier.editKit)
        XCTAssertTrue(edit.waitForExistence(timeout: defaultTimeout))
        edit.tap()

        let title = element(Identifier.kitEditTitle)
        let kpi = element(Identifier.kitEditKPI)
        XCTAssertTrue(title.waitForExistence(timeout: defaultTimeout))
        XCTAssertTrue(kpi.waitForExistence(timeout: defaultTimeout))
        replaceText(in: title, with: editedFixtureTitle)
        replaceText(in: kpi, with: editedFixtureKPI)

        let save = element(Identifier.kitEditSave)
        XCTAssertTrue(save.isEnabled)
        save.tap()
        // El KPI se ve en los detalles del Kit, no en la pantalla del plan.
        XCTAssertTrue(app.staticTexts[editedFixtureKPI].waitForExistence(timeout: defaultTimeout))
        let close = element(Identifier.kitInfoClose)
        XCTAssertTrue(close.waitForExistence(timeout: defaultTimeout))
        close.tap()
        XCTAssertTrue(app.staticTexts[editedFixtureTitle].waitForExistence(timeout: defaultTimeout))
        return checkpoint
    }

    @MainActor
    private func editFirstStep() -> SyncCheckpoint {
        let checkpoint = currentSyncCheckpoint()
        let edit = element(Identifier.editStep)
        XCTAssertTrue(edit.waitForExistence(timeout: defaultTimeout))
        edit.tap()

        let title = element(Identifier.stepEditTitle)
        let shortDescription = element(Identifier.stepEditShortDescription)
        XCTAssertTrue(title.waitForExistence(timeout: defaultTimeout))
        XCTAssertTrue(shortDescription.waitForExistence(timeout: defaultTimeout))
        replaceText(in: title, with: editedFirstStep)
        replaceText(in: shortDescription, with: editedFirstStepDescription)

        let save = element(Identifier.stepEditSave)
        XCTAssertTrue(save.isEnabled)
        save.tap()
        XCTAssertTrue(app.staticTexts[editedFirstStep].waitForExistence(timeout: defaultTimeout))
        XCTAssertTrue(app.staticTexts[editedFirstStepDescription].waitForExistence(timeout: defaultTimeout))
        return checkpoint
    }

    @MainActor
    private func assertFirstStepIsCompleted() {
        returnToKitsRoot()
        let row = kitRows
            .matching(NSPredicate(format: "label == %@", "Kit: \(editedFixtureTitle)"))
            .firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: defaultTimeout))
        row.tap()
        XCTAssertTrue(app.staticTexts[editedFixtureTitle].waitForExistence(timeout: defaultTimeout))

        let firstStep = stepRows
            .matching(NSPredicate(format: "label CONTAINS %@", editedFirstStep))
            .firstMatch
        XCTAssertTrue(firstStep.waitForExistence(timeout: defaultTimeout))
        firstStep.tap()

        XCTAssertTrue(app.staticTexts[editedFirstStepDescription].waitForExistence(timeout: defaultTimeout))

        let completionButton = element(Identifier.toggleCompletion)
        XCTAssertTrue(completionButton.waitForExistence(timeout: defaultTimeout))
        XCTAssertEqual(completionButton.label, "Marcar como pendiente")
        XCTAssertEqual(completionButton.value as? String, "Completado")
    }

    @MainActor
    private func assertFixtureKitCount(_ expectedCount: Int, title: String) {
        let matchingRows = kitRows.matching(NSPredicate(format: "label == %@", "Kit: \(title)"))
        XCTAssertTrue(waitUntil(timeout: defaultTimeout) {
            matchingRows.count == expectedCount
        })
        XCTAssertEqual(matchingRows.count, expectedCount)
        XCTAssertEqual(kitRows.count, expectedCount)
    }

    @MainActor
    private func deleteAllVisibleKits() {
        var remainingSafetyLimit = 20
        while kitRows.count > 0, remainingSafetyLimit > 0 {
            let checkpoint = currentSyncCheckpoint()
            deleteFirstVisibleKit()
            waitForSyncAdvance(from: checkpoint, operation: "limpiar un Kit residual")
            remainingSafetyLimit -= 1
        }
        XCTAssertGreaterThan(remainingSafetyLimit, 0, "La limpieza encontró demasiados Kits residuales")
        XCTAssertEqual(kitRows.count, 0)
    }

    @MainActor
    private func deleteFirstVisibleKit() {
        let previousCount = kitRows.count
        let row = kitRows.firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: defaultTimeout))
        if !row.isHittable {
            app.swipeDown()
        }
        row.swipeLeft()

        let swipeDelete = app.buttons["Eliminar"].firstMatch
        XCTAssertTrue(swipeDelete.waitForExistence(timeout: defaultTimeout))
        swipeDelete.tap()

        let confirm = element(Identifier.confirmDelete)
        XCTAssertTrue(confirm.waitForExistence(timeout: defaultTimeout))
        confirm.tap()
        XCTAssertTrue(waitUntil(timeout: defaultTimeout) {
            self.kitRows.count < previousCount
        })
    }

    // MARK: - Sync diagnostics

    @MainActor
    private func currentOwnerID() -> String {
        stateComponent(named: "owner")
    }

    @MainActor
    private func currentSyncCursor() -> String {
        stateComponent(named: "cursor")
    }

    @MainActor
    private func currentSyncCheckpoint() -> SyncCheckpoint {
        SyncCheckpoint(
            cursor: currentSyncCursor(),
            completedCount: Int(stateComponent(named: "completed")) ?? -1
        )
    }

    @MainActor
    private func stateComponent(named name: String) -> String {
        let state = element(Identifier.appState)
        XCTAssertTrue(state.waitForExistence(timeout: defaultTimeout))
        guard let value = state.value as? String else {
            XCTFail("El marcador E2E no expone un valor")
            return "missing"
        }

        let prefix = "\(name)="
        guard let component = value
            .split(separator: ";")
            .map(String.init)
            .first(where: { $0.hasPrefix(prefix) }) else {
            XCTFail("No se encontró \(name) en \(value)")
            return "missing"
        }
        return String(component.dropFirst(prefix.count))
    }

    @MainActor
    private func waitForSyncAdvance(from checkpoint: SyncCheckpoint, operation: String) {
        let state = element(Identifier.appState)
        let predicate = NSPredicate { object, _ in
            guard let element = object as? XCUIElement,
                  let value = element.value as? String else {
                return false
            }
            let components = Dictionary(uniqueKeysWithValues: value
                .split(separator: ";")
                .compactMap { component -> (String, String)? in
                    let pair = component.split(separator: "=", maxSplits: 1).map(String.init)
                    guard pair.count == 2 else { return nil }
                    return (pair[0], pair[1])
                })
            guard let completed = components["completed"].flatMap(Int.init) else {
                return false
            }
            return components["sync"] == "idle"
                && components["cursor"] != "never"
                && components["cursor"] != checkpoint.cursor
                && completed > checkpoint.completedCount
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: state)
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation], timeout: defaultTimeout),
            .completed,
            "No se confirmó sync después de \(operation): \(state.value ?? "sin valor")"
        )
    }

    // MARK: - Queries and evidence

    @MainActor
    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    @MainActor
    private var kitRows: XCUIElementQuery {
        app.descendants(matching: .any).matching(identifier: Identifier.kitRow)
    }

    @MainActor
    private var stepRows: XCUIElementQuery {
        app.descendants(matching: .any).matching(identifier: Identifier.stepRow)
    }

    @MainActor
    private func waitUntil(timeout: TimeInterval, condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        } while Date() < deadline
        return condition()
    }

    @MainActor
    private func scrollUpUntilHittable(_ element: XCUIElement, maxSwipes: Int = 6) {
        var remainingSwipes = maxSwipes
        while !element.isHittable, remainingSwipes > 0 {
            app.swipeUp()
            remainingSwipes -= 1
        }
        XCTAssertTrue(element.isHittable, "El elemento no llegó a una posición interactuable")
    }

    @MainActor
    private func replaceText(in element: XCUIElement, with replacement: String) {
        // The lower trailing edge places the caret after the last character,
        // including fields that wrap onto more than one line.
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.95)).tap()
        let existingText = element.value as? String ?? ""
        if !existingText.isEmpty {
            // Explicit delete events do not depend on the Mac's Command-A shortcut.
            element.typeText(String(
                repeating: XCUIKeyboardKey.delete.rawValue,
                count: existingText.count
            ))
            let clearedValue = element.value as? String ?? ""
            XCTAssertTrue(
                clearedValue.isEmpty || clearedValue == element.placeholderValue,
                "El campo debe vaciarse antes de reemplazarlo: \(clearedValue)"
            )
        }
        element.typeText(replacement)
        XCTAssertEqual(element.value as? String, replacement)
    }

    @MainActor
    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
