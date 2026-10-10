// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation
import Testing

@testable import ArknightsClient

@MainActor
@Suite("Game compatibility error")
struct GameCompatibilityErrorTests {
	@Test("Compatibility failures keep the published support code, message, and diagnostic")
	func compatibilityErrorContract() {
		let error = GameCompatibilityError.setupFailed("shim")

		#expect(InstallationController.supportCode(for: error) == .anemone)
		#expect(
			error.errorDescription
				== "Game-file compatibility setup could not be completed. Repair the game files and try again."
		)
		#expect(
			error.diagnosticDescription
				== "Game compatibility setup could not be completed: shim")
	}

	@Test("Runtime maps compatibility failures to the same code, message, and diagnostic")
	func runtimeMappingPreservesContract() {
		let compatibility = GameCompatibilityError.setupFailed("shim")
		let mapped = GameRuntimeError.mappingCompatibilityFailure(compatibility)

		#expect(mapped is GameRuntimeError)
		#expect(GameSessionController.supportCode(for: mapped) == .anemone)
		#expect(launcherUserMessage(for: mapped) == launcherUserMessage(for: compatibility))
		#expect(
			launcherDiagnosticDescription(for: mapped)
				== launcherDiagnosticDescription(for: compatibility))
	}

	@Test("Runtime mapping leaves unrelated errors untouched")
	func runtimeMappingPassesOtherErrorsThrough() {
		let other = GameRuntimeError.wineRuntimeMissing
		let mapped = GameRuntimeError.mappingCompatibilityFailure(other)

		#expect(mapped is GameRuntimeError)
		#expect(GameSessionController.supportCode(for: mapped) == .whelk)
	}
}
