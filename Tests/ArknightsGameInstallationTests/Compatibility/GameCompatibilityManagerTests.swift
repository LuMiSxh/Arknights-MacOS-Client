// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsGameInstallation

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
func compatibilityManagerInstallsActiveRemovesRetiredAndRestoresBeforeUpdates() throws {
	let active = TestCompatibilityComponent(identifier: "active", installs: true, restores: true)
	let retired = TestCompatibilityComponent(identifier: "retired", installs: false, restores: true)
	let manager = GameCompatibilityManager(active: [active], retired: [retired])

	let changes = try manager.prepareForLaunch(in: URL(filePath: "/game"))

	#expect(changes == GameCompatibilityChanges(installed: ["active"], removed: ["retired"]))
	#expect(try manager.restoreForUpdate(in: URL(filePath: "/game")) == ["active", "retired"])
}
