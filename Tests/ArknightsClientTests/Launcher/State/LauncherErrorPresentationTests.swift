// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@MainActor
struct LauncherErrorPresentationTests {
	@Test(
		arguments: [
			(
				LauncherError.server(code: 503, message: "upstream-internal-detail"),
				["503", "upstream-internal-detail"]
			),
			(.invalidManifestPath("../private-file"), ["../private-file"]),
			(.duplicateManifestPath("private-file"), ["private-file"]),
			(
				.conflictingManifestPaths("private-parent", "private-child"),
				["private-parent", "private-child"]
			),
			(
				.symbolicLinkInInstallPath(URL(filePath: "/private/install-link")),
				["/private/install-link"]
			),
			(.invalidDownloadResponse(status: 403, path: "private-file"), ["403", "private-file"]),
			(
				.remoteContentTooLarge(
					URL(string: "https://private.example/file")!, maximumBytes: 1),
				["private.example"]
			),
			(
				.invalidRemoteAsset(URL(string: "https://private.example/file")!),
				["https://private.example/file"]
			),
			(
				.invalidPresetImage(URL(string: "https://private.example/image")!),
				["https://private.example/image"]
			),
			(
				.invalidCustomImage(URL(filePath: "/private/custom-image")),
				["/private/custom-image"]
			),
			(
				.downloadedSizeMismatch(path: "private-file", expected: 12345, actual: 54321),
				["private-file", "12345", "54321"]
			),
			(
				.checksumMismatch(path: "private-file", expected: "deadbeef", actual: "badcafe"),
				["private-file", "deadbeef", "badcafe"]
			),
			(.cannotCreateFile(URL(filePath: "/private/log-file")), ["/private/log-file"]),
			(
				.unsafeInstallerTemporaryFile(URL(filePath: "/private/game.part")),
				["/private/game.part"]
			),
			(
				.gameNotInstalled(URL(filePath: "/private/game/Arknights.exe")),
				["/private/game/Arknights.exe"]
			),
			(.runtimeConfiguration("runtime-internal-detail"), ["runtime-internal-detail"]),
			(
				.gameCompatibility("compatibility-internal-detail"),
				["compatibility-internal-detail"]
			),
			(
				.runtimeExited(status: 123, log: URL(filePath: "/private/wine.log")),
				["123", "/private/wine.log"]
			),
			(.storageMigrationFailed("migration-internal-detail"), ["migration-internal-detail"]),
		]
	)
	func failureDialogsKeepTechnicalDetailsInTheLog(fixture: (LauncherError, [String])) async throws
	{
		let fileURL = FileManager.default.temporaryDirectory.appending(
			path: "LauncherErrorPresentationTests.\(UUID().uuidString).log"
		)
		let log = LauncherLog(fileURL: fileURL)
		let lifecycle = LauncherLifecycleStore(log: log)

		lifecycle.show(fixture.0)
		await log.flush()

		let message = try #require(lifecycle.failureMessage)
		let diagnostic = try String(contentsOf: fileURL, encoding: .utf8)
		try FileManager.default.removeItem(at: fileURL)
		#expect(!message.isEmpty)
		for detail in fixture.1 {
			#expect(!message.contains(detail))
			#expect(diagnostic.contains(detail))
		}
	}
}
