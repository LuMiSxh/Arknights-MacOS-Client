// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

private struct TestCompatibilityComponent: GameCompatibilityComponent {
	let identifier: String
	let installs: Bool
	let restores: Bool

	func installIfSupported(in gameDirectory: URL, fileManager: FileManager) throws -> Bool {
		installs
	}

	func restoreIfInstalled(in gameDirectory: URL, fileManager: FileManager) throws -> Bool {
		restores
	}
}

@Test
func compatibilityManagerInstallsActiveAndRemovesRetiredComponents() throws {
	let active = TestCompatibilityComponent(
		identifier: "active",
		installs: true,
		restores: false
	)
	let retired = TestCompatibilityComponent(
		identifier: "retired",
		installs: false,
		restores: true
	)
	let manager = GameCompatibilityManager(active: [active], retired: [retired])

	let changes = try manager.prepareForLaunch(in: URL(filePath: "/game"))

	#expect(changes == GameCompatibilityChanges(installed: ["active"], removed: ["retired"]))
}

@Test
func compatibilityManagerRestoresActiveAndRetiredComponentsBeforeUpdates() throws {
	let active = TestCompatibilityComponent(
		identifier: "active",
		installs: true,
		restores: true
	)
	let retired = TestCompatibilityComponent(
		identifier: "retired",
		installs: false,
		restores: true
	)
	let manager = GameCompatibilityManager(active: [active], retired: [retired])

	#expect(
		try manager.restoreForUpdate(in: URL(filePath: "/game"))
			== ["active", "retired"]
	)
}

@Test
func compatibilityManagerRejectsDuplicateComponentIdentifiers() {
	let component = TestCompatibilityComponent(
		identifier: "duplicate",
		installs: false,
		restores: false
	)
	let manager = GameCompatibilityManager(active: [component], retired: [component])

	#expect(throws: LauncherError.self) {
		try manager.prepareForLaunch(in: URL(filePath: "/game"))
	}
}
