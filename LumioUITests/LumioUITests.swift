import XCTest

final class LumioUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testOnboardingFlowExists() throws {
        // Placeholder: onboarding should be visible on first launch
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["Lumio"].waitForExistence(timeout: 3))
    }

    /// Walks Today → Settings and attaches a screenshot of each screen
    /// (visible under the test report's attachments).
    @MainActor
    func testScreenshotTour() throws {
        let app = XCUIApplication()
        // Argument domain overrides stored defaults: skip onboarding, force
        // German UI — deterministic regardless of simulator state.
        app.launchArguments += [
            "-hasCompletedOnboarding", "YES",
            "-selectedLanguage", "de",
        ]

        // Dismiss system permission alerts (calendar, reminders, location).
        addUIInterruptionMonitor(withDescription: "System permission alerts") { alert in
            let allowLabels = [
                "Vollen Zugriff erlauben", "Beim Verwenden der App erlauben",
                "Einmal erlauben", "Erlauben",
                "Allow Full Access", "Allow While Using App", "Allow Once", "Allow", "OK",
            ]
            for label in allowLabels where alert.buttons[label].exists {
                alert.buttons[label].tap()
                return true
            }
            return false
        }

        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "Tab bar not found after launch")
        // Interacting is what triggers the interruption monitor; tapping the
        // current tab is a harmless nudge. Repeat once for late alerts
        // (the location prompt arrives after the weather fetch starts).
        tabBar.buttons.firstMatch.tap()
        Thread.sleep(forTimeInterval: 3)
        tabBar.buttons.firstMatch.tap()

        // Wait for the live AI summary: the generating indicator appears once
        // events + weather settled (≤ ~3 s) and disappears when the on-device
        // model finished. If it never shows up, generation was already done.
        let generating = app.staticTexts["Briefing wird vorbereitet…"]
        _ = generating.waitForExistence(timeout: 8)
        for _ in 0..<30 where generating.exists {
            Thread.sleep(forTimeInterval: 1)
        }
        Thread.sleep(forTimeInterval: 1) // let the summary card fade in

        attachScreenshot(of: app, named: "01-Today")

        // Settings tab — German title first, English fallback.
        let settingsTab = tabBar.buttons["Einstellungen"].exists
            ? tabBar.buttons["Einstellungen"]
            : tabBar.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5), "Settings tab not found")
        settingsTab.tap()
        attachScreenshot(of: app, named: "02-Settings")
    }

    @MainActor
    private func attachScreenshot(of app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
