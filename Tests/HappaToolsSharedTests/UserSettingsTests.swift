import Foundation
import XCTest
@testable import HappaToolsShared

final class UserSettingsTests: XCTestCase {
    func testDefaultsAndPersistenceAcrossInstances() {
        let suite = "HappaToolsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = UserSettings(defaults: defaults)
        XCTAssertEqual(settings.defaultBranch, "main")
        XCTAssertTrue(settings.showGitButton)
        XCTAssertTrue(settings.showReadmeButton)
        XCTAssertFalse(settings.onboardingCompleted)
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: settings.gitExecutablePath))

        settings.defaultBranch = "release"
        settings.gitExecutablePath = "/custom/git"
        settings.showGitButton = false
        settings.showReadmeButton = false
        settings.onboardingCompleted = true

        let reopened = UserSettings(defaults: UserDefaults(suiteName: suite)!)
        XCTAssertEqual(reopened.defaultBranch, "release")
        XCTAssertEqual(reopened.gitExecutablePath, "/custom/git")
        XCTAssertFalse(reopened.showGitButton)
        XCTAssertFalse(reopened.showReadmeButton)
        XCTAssertTrue(reopened.onboardingCompleted)
    }
}
