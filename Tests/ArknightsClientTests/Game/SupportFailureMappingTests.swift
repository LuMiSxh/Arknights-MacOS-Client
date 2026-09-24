// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@MainActor
struct SupportFailureMappingTests {
	@Test(
		arguments: [
			(LauncherError.invalidResponse as any Error, SupportCode.pebble),
			(
				LauncherError.remoteContentTooLarge(
					URL(string: "https://cdn.example/game.bin")!, maximumBytes: 1
				) as any Error,
				.pebble
			),
			(LauncherError.server(code: 500, message: "test") as any Error, .virga),
			(LauncherError.invalidManifestPath("../test") as any Error, .gabbro),
			(
				LauncherError.symbolicLinkInInstallPath(URL(filePath: "/tmp/test")) as any Error,
				.basalt
			),
			(LauncherError.insufficientDiskSpace(required: 2, available: 1) as any Error, .scree),
			(
				LauncherError.checksumMismatch(path: "test", expected: "a", actual: "b")
					as any Error, .pebble
			),
			(URLError(.networkConnectionLost) as any Error, .pebble),
			(CocoaError(.fileWriteNoPermission) as any Error, .basalt),
			(LauncherError.gameCompatibility("test") as any Error, .anemone),
			(
				HTTPTransportError.responseTooLarge(
					URL(string: "https://cdn.example/game.bin")!, maximumBytes: 1
				) as any Error,
				.pebble
			),
		]
	)
	func installationFailuresMapToPublishedCodes(
		fixture: (any Error, SupportCode)
	) {
		#expect(InstallationController.supportCode(for: fixture.0) == fixture.1)
	}

	@Test(
		arguments: [
			(
				LauncherError.wineRuntimeMissing as any Error, SupportCode.whelk
			),
			(LauncherError.rosettaMissing as any Error, .limpet),
			(LauncherError.runtimeConfiguration("test") as any Error, .sepia),
			(LauncherError.runtimeWindowTimeout as any Error, .narwhal),
			(
				LauncherError.runtimeExited(status: 1, log: URL(filePath: "/tmp/test"))
					as any Error, .crux
			),
			(
				LauncherError.gameNotInstalled(URL(filePath: "/tmp/Arknights.exe")) as any Error,
				.pebble
			),
			(CocoaError(.fileWriteNoPermission) as any Error, .sepia),
			(LauncherError.gameCompatibility("test") as any Error, .anemone),
			(
				WineRuntimeDiscoveryError.missingResourceDirectory as any Error, .whelk
			),
		]
	)
	func runtimeFailuresMapToPublishedCodes(
		fixture: (any Error, SupportCode)
	) {
		#expect(GameSessionController.supportCode(for: fixture.0) == fixture.1)
	}

}
