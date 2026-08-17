// SPDX-License-Identifier: MPL-2.0

import Foundation

protocol GameCompatibilityComponent: Sendable {
	var identifier: String { get }

	@discardableResult
	func installIfSupported(in gameDirectory: URL, fileManager: FileManager) throws -> Bool

	@discardableResult
	func restoreIfInstalled(in gameDirectory: URL, fileManager: FileManager) throws -> Bool
}

struct GameCompatibilityChanges: Equatable, Sendable {
	var installed: [String] = []
	var removed: [String] = []
}

struct GameCompatibilityManager: Sendable {
	private let active: [any GameCompatibilityComponent]
	private let retired: [any GameCompatibilityComponent]

	init(bundle: Bundle = .main) {
		// Add new components to active. Move removed components to retired for at
		// least one supported upgrade cycle so their owned files are restored.
		active = [
			VuplexCompatibility(bundle: bundle),
			PlatformProcessCompatibility(bundle: bundle),
		]
		retired = []
	}

	init(
		active: [any GameCompatibilityComponent],
		retired: [any GameCompatibilityComponent] = []
	) {
		self.active = active
		self.retired = retired
	}

	func prepareForLaunch(
		in gameDirectory: URL,
		fileManager: FileManager = .default
	) throws -> GameCompatibilityChanges {
		try validateIdentifiers()
		var changes = GameCompatibilityChanges()
		for component in retired
		where try component.restoreIfInstalled(
			in: gameDirectory,
			fileManager: fileManager
		) {
			changes.removed.append(component.identifier)
		}
		for component in active
		where try component.installIfSupported(
			in: gameDirectory,
			fileManager: fileManager
		) {
			changes.installed.append(component.identifier)
		}
		return changes
	}

	@discardableResult
	func restoreForUpdate(
		in gameDirectory: URL,
		fileManager: FileManager = .default
	) throws -> [String] {
		try validateIdentifiers()
		var restored: [String] = []
		for component in active + retired
		where try component.restoreIfInstalled(
			in: gameDirectory,
			fileManager: fileManager
		) {
			restored.append(component.identifier)
		}
		return restored
	}

	private func validateIdentifiers() throws {
		let identifiers = (active + retired).map(\.identifier)
		guard Set(identifiers).count == identifiers.count else {
			throw LauncherError.runtimeConfiguration(
				"Game compatibility component identifiers must be unique."
			)
		}
	}
}
