// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@MainActor
struct SupportFailureMappingTests {
	@Test(
		arguments: [
			(LauncherError.invalidResponse as any Error, SupportCode.pebble),
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
				LauncherError.wineRuntimeMissing as any Error, SupportOperation.launch,
				SupportCode.whelk
			),
			(LauncherError.rosettaMissing as any Error, .launch, .limpet),
			(LauncherError.runtimeConfiguration("test") as any Error, .launch, .sepia),
			(LauncherError.runtimeWindowTimeout as any Error, .launch, .narwhal),
			(
				LauncherError.runtimeExited(status: 1, log: URL(filePath: "/tmp/test"))
					as any Error, .runtimeExit, .crux
			),
			(
				LauncherError.gameNotInstalled(URL(filePath: "/tmp/Arknights.exe")) as any Error,
				.launch, .pebble
			),
			(CocoaError(.fileWriteNoPermission) as any Error, .launch, .sepia),
			(LauncherError.gameCompatibility("test") as any Error, .launch, .anemone),
			(
				WineRuntimeDiscoveryError.missingResourceDirectory as any Error, .runtimeDiscovery,
				.whelk
			),
		]
	)
	func runtimeFailuresMapToPublishedCodes(
		fixture: (any Error, SupportOperation, SupportCode)
	) {
		#expect(
			GameSessionController.supportCode(for: fixture.0, operation: fixture.1)
				== fixture.2
		)
	}

	@Test
	func recoveryActionsRemainOrderedAndContextual() {
		#expect(
			InstallationController.recoveryActions(
				for: .pebble,
				isInstalled: true,
				operation: .update
			)
				== [.retry, .openTroubleshooting, .repair, .reportProblem]
		)
		#expect(
			InstallationController.recoveryActions(
				for: .pebble,
				isInstalled: true,
				operation: .repair
			)
				== [.retry, .openTroubleshooting, .reportProblem]
		)
		#expect(
			InstallationController.recoveryActions(
				for: .virga,
				isInstalled: false,
				operation: .install,
				allowsRetry: false
			)
				== [.openTroubleshooting, .reportProblem]
		)
		#expect(
			GameSessionController.recoveryActions(
				for: .anemone,
				isInstalled: true,
				operation: .runtimeStop
			)
				== [.retry, .openTroubleshooting, .reportProblem]
		)
		#expect(
			GameSessionController.recoveryActions(
				for: .narwhal,
				isInstalled: true,
				operation: .launch
			)
				== [.retry, .openTroubleshooting, .repair, .reportProblem]
		)
	}
}
