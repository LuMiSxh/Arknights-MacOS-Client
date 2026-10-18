// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation

// Components share `GameShimIO`'s swap and marker checks, so each one behaves identically.
protocol GameCompatibilityComponent: Sendable {
	var identifier: String { get }

	@discardableResult
	func installIfSupported(in gameDirectory: URL, fileManager: FileManager) throws -> Bool

	@discardableResult
	func restoreIfInstalled(in gameDirectory: URL, fileManager: FileManager) throws -> Bool
}

package struct GameCompatibilityChanges: Equatable, Sendable {
	package var installed: [String] = []
	package var removed: [String] = []
}

/// Applies every active compatibility component on launch and restores retired ones on
/// update, so a component removed in a later release still gets uninstalled from prefixes
/// that installed it under an older build.
package struct GameCompatibilityManager: Sendable {
	private let active: [any GameCompatibilityComponent]
	private let retired: [any GameCompatibilityComponent]

	package init(bundle: Bundle = .main) {
		// Add new components to active. Move removed components to retired for at
		// least one supported upgrade cycle so their owned files are restored.
		active = [
			VuplexCompatibility(bundle: bundle),
			PlatformProcessCompatibility(bundle: bundle),
			BilibiliPlatformCompatibility(bundle: bundle),
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

	package func prepareForLaunch(
		in gameDirectory: URL,
		fileManager: FileManager = .default
	) throws -> GameCompatibilityChanges {
		do {
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
		} catch {
			throw Self.compatibilityError(from: error)
		}
	}

	@discardableResult
	func restoreForUpdate(
		in gameDirectory: URL,
		fileManager: FileManager = .default
	) throws -> [String] {
		do {
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
		} catch {
			throw Self.compatibilityError(from: error)
		}
	}

	private func validateIdentifiers() throws {
		let identifiers = (active + retired).map(\.identifier)
		guard Set(identifiers).count == identifiers.count else {
			throw GameCompatibilityError.setupFailed(
				"Game compatibility component identifiers must be unique."
			)
		}
	}

	private static func compatibilityError(from error: any Error) -> GameCompatibilityError {
		if case GameCompatibilityError.setupFailed(let message) = error {
			return .setupFailed(message)
		}
		return .setupFailed(launcherDiagnosticDescription(for: error))
	}
}
