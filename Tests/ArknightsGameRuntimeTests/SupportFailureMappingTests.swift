// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation
import Testing

@testable import ArknightsGameInstallation
@testable import ArknightsGameRuntime
@testable import ArknightsInfrastructure

// `SupportCodeStabilityTests` pins the launcher's own errors. This test pins errors
// that other frameworks and layers throw.
@MainActor
struct SupportFailureMappingTests {
	@Test(
		arguments: [
			(URLError(.networkConnectionLost) as any Error, SupportCode.pebble),
			(CocoaError(.fileWriteNoPermission) as any Error, .basalt),
			(
				HTTPTransportError.responseTooLarge(
					URL(string: "https://cdn.example/game.bin")!, maximumBytes: 1
				) as any Error,
				.pebble
			),
		]
	)
	func installationFailuresMapToPublishedCodes(fixture: (any Error, SupportCode)) {
		#expect(InstallationController.supportCode(for: fixture.0) == fixture.1)
	}

	@Test func foreignRuntimeFailuresMapToTheRuntimeConfigurationCode() {
		let compatibility = GameRuntimeError.mappingCompatibilityFailure(
			GameCompatibilityError.setupFailed("test"))
		#expect(GameSessionController.supportCode(for: compatibility) == .anemone)
		#expect(
			GameSessionController.supportCode(for: CocoaError(.fileWriteNoPermission)) == .sepia)
		#expect(
			GameSessionController.supportCode(
				for: WineRuntimeDiscoveryError.missingResourceDirectory)
				== .whelk)
	}
}
