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
			(InstallerError.invalidManifestPath("../test") as any Error, .gabbro),
			(
				InstallerError.symbolicLinkInInstallPath(URL(filePath: "/tmp/test")) as any Error,
				.basalt
			),
			(InstallerError.insufficientDiskSpace(required: 2, available: 1) as any Error, .scree),
			(
				InstallerError.checksumMismatch(path: "test", expected: "a", actual: "b")
					as any Error, .pebble
			),
			(URLError(.networkConnectionLost) as any Error, .pebble),
			(CocoaError(.fileWriteNoPermission) as any Error, .basalt),
			(GameRuntimeError.gameCompatibility("test") as any Error, .anemone),
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
				GameRuntimeError.wineRuntimeMissing as any Error, SupportCode.whelk
			),
			(GameRuntimeError.rosettaMissing as any Error, .limpet),
			(GameRuntimeError.runtimeConfiguration("test") as any Error, .sepia),
			(GameRuntimeError.runtimeWindowTimeout as any Error, .narwhal),
			(
				GameRuntimeError.runtimeExited(status: 1, log: URL(filePath: "/tmp/test"))
					as any Error, .crux
			),
			(
				GameRuntimeError.gameNotInstalled(URL(filePath: "/tmp/Arknights.exe")) as any Error,
				.pebble
			),
			(CocoaError(.fileWriteNoPermission) as any Error, .sepia),
			(GameRuntimeError.gameCompatibility("test") as any Error, .anemone),
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
