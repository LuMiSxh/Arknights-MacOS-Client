// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

// Edit only this table when a `LauncherError` case changes. Each row pins the
// support code, `errorDescription`, and `diagnosticDescription` of one case.
private let supportCodeStabilityCases:
	[(any LauncherDiagnosticError & Sendable, SupportCode?, String, String)] = [
		(
			LauncherError.invalidResponse, .pebble,
			"The game service returned an unexpected response. Try again later.",
			"The game service returned an invalid response."
		),
		(
			LauncherError.server(code: 500, message: "test"), .virga,
			"The game service reported an error. Try again later.",
			"Game service API error 500: test"
		),
		(
			InstallerError.invalidManifestPath("../test"), .gabbro,
			"The game's file list contains unsafe or conflicting paths. Installation was stopped. Try again later.",
			"Unsafe path in game manifest: ../test"
		),
		(
			InstallerError.duplicateManifestPath("a"), .gabbro,
			"The game's file list contains unsafe or conflicting paths. Installation was stopped. Try again later.",
			"Duplicate path in game manifest: a"
		),
		(
			InstallerError.conflictingManifestPaths("a", "b"), .gabbro,
			"The game's file list contains unsafe or conflicting paths. Installation was stopped. Try again later.",
			"Conflicting paths in game manifest: a and b"
		),
		(
			InstallerError.symbolicLinkInInstallPath(URL(filePath: "/tmp/test")), .basalt,
			"The install folder contains a symbolic link. Choose a regular folder and try again.",
			"The game installer refused a symbolic link in its destination: /tmp/test"
		),
		(
			InstallerError.invalidDownloadResponse(status: 404, path: "game.bin"), .pebble,
			"A game file could not be downloaded. Check your connection and try again.",
			"Download for game.bin returned HTTP 404."
		),
		(
			LauncherError.remoteContentTooLarge(
				URL(string: "https://cdn.example/game.bin")!, maximumBytes: 1_000_000), .pebble,
			"The requested content exceeds the launcher's size limit and cannot be used. Check for a launcher update and try again.",
			"Remote content from cdn.example exceeded the 1 MB limit."
		),
		(
			CustomizationError.invalidRemoteAsset(URL(string: "http://cdn.example/a")!), .pebble,
			"The requested content uses an unsupported download address. Check for a launcher update and try again.",
			"Refused an unsupported remote asset URL: http://cdn.example/a"
		),
		(
			CustomizationError.invalidPresetImage(URL(string: "https://cdn.example/p.png")!), nil,
			"The gallery image could not be used. Choose another image.",
			"The preset asset is not a supported image or has unsafe dimensions: https://cdn.example/p.png"
		),
		(
			CustomizationError.invalidCustomImage(URL(filePath: "/tmp/c.txt")), nil,
			"The selected file is not a supported image. Choose another image.",
			"The selected file is not a supported image: /tmp/c.txt"
		),
		(
			CustomizationError.cannotEncodeAppIcon, nil,
			"The selected image could not be converted into an app icon.",
			"The selected image could not be converted into an app icon."
		),
		(
			CustomizationError.cannotSetAppIcon, nil,
			"macOS refused to update the app icon.",
			"macOS refused to update the app icon."
		),
		(
			InstallerError.downloadedSizeMismatch(path: "a.bin", expected: 10, actual: 5), .pebble,
			"A downloaded file was damaged or incomplete. Try again to download the file again.",
			"a.bin has 5 bytes instead of 10."
		),
		(
			InstallerError.checksumMismatch(path: "a.bin", expected: "x", actual: "y"), .pebble,
			"A downloaded file was damaged or incomplete. Try again to download the file again.",
			"Checksum check for a.bin failed (y, expected x)."
		),
		(
			InstallerError.cannotCreateFile(URL(filePath: "/tmp/f")), .basalt,
			"The launcher could not create a file. Check folder permissions and free disk space, then try again.",
			"Could not create temporary file: /tmp/f"
		),
		(
			InstallerError.unsafeInstallerTemporaryFile(URL(filePath: "/tmp/t")), .basalt,
			"The launcher could not safely write to the install folder. Choose another folder and try again.",
			"The installer refused a non-regular or multiply linked temporary file: /tmp/t"
		),
		(
			InstallerError.installDirectoryInUse(URL(filePath: "/tmp/i")), .basalt,
			"Another launcher process is changing this install folder. Wait for it to finish and try again.",
			"Another launcher process holds the install lease for /tmp/i."
		),
		(
			InstallerError.missingConfiguration, .virga,
			"Game information has not loaded yet. Refresh the launcher and try again.",
			"The current game configuration has not been loaded yet."
		),
		(
			GameRuntimeError.gameNotInstalled(URL(filePath: "/tmp/g")), .pebble,
			"Arknights.exe was not found in the install folder. Install the game or locate an existing installation.",
			"Arknights.exe was not found: /tmp/g"
		),
		(
			InstallerError.insufficientDiskSpace(required: 2_000_000_000, available: 1_000_000),
			.scree,
			"Arknights needs about 2 GB free, but only 1 MB is available. Free up space and try again.",
			"Arknights needs about 2 GB free, but only 1 MB is available. Free up space and try again."
		),
		(
			GameRuntimeError.wineRuntimeMissing, .whelk,
			"No compatible Windows runtime found. Use a build that bundles Wine + DXMT.",
			"No compatible Windows runtime found. Use a build that bundles Wine + DXMT."
		),
		(
			GameRuntimeError.rosettaMissing, .limpet,
			"Rosetta 2 is required to run the bundled Wine runtime. Install it by running \"softwareupdate --install-rosetta --agree-to-license\" in Terminal, then check again.",
			"Rosetta 2 is required to run the bundled Wine runtime. Install it by running \"softwareupdate --install-rosetta --agree-to-license\" in Terminal, then check again."
		),
		(
			GameRuntimeError.rosettaDisabledByGameTestMode, .limpet,
			"On macOS 27 beta, Legacy Game Test Mode disables the Rosetta translation required by Wine. Run \"sudo game-test-tool disable\" in Terminal, restart your Mac, then check again.",
			"On macOS 27 beta, Legacy Game Test Mode disables the Rosetta translation required by Wine. Run \"sudo game-test-tool disable\" in Terminal, restart your Mac, then check again."
		),
		(
			GameRuntimeError.intelTranslationUnavailable, .limpet,
			"macOS could not start the Intel-based Wine runtime. Check that Rosetta 2 is installed and restart your Mac before trying again.",
			"macOS could not start the Intel-based Wine runtime. Check that Rosetta 2 is installed and restart your Mac before trying again."
		),
		(
			GameRuntimeError.intelTranslationUnsupported, .limpet,
			"The launcher currently blocks this macOS version. Apple retains Rosetta only for certain legacy games, and whether this Wine and game setup qualifies is unconfirmed.",
			"The launcher currently blocks this macOS version. Apple retains Rosetta only for certain legacy games, and whether this Wine and game setup qualifies is unconfirmed."
		),
		(
			GameRuntimeError.runtimeWindowTimeout, .narwhal,
			"Arknights did not open a window within 90 seconds. Check the Wine log in Settings and try again.",
			"Arknights did not open a window within 90 seconds. Check the Wine log in Settings and try again."
		),
		(
			GameRuntimeError.runtimeConfiguration("cfg"), .sepia,
			"The Windows runtime could not complete the operation. Check the Wine log in Settings and try again.",
			"The Windows runtime could not be configured: cfg"
		),
		(
			GameRuntimeError.gameCompatibility("shim"), .anemone,
			"Game-file compatibility setup could not be completed. Repair the game files and try again.",
			"Game compatibility setup could not be completed: shim"
		),
		(
			GameRuntimeError.runtimeExited(status: 1, log: URL(filePath: "/tmp/wine.log")), .crux,
			"Arknights closed unexpectedly. Check the Wine log in Settings and try again.",
			"The Windows runtime exited with status 1. See /tmp/wine.log."
		),
		(
			LauncherError.storageMigrationFailed("disk"), .basalt,
			"Launcher data could not be updated. Check the logs and try again.",
			"Application storage migration failed: disk"
		),
	]

@MainActor
struct SupportCodeStabilityTests {
	@Test(arguments: supportCodeStabilityCases)
	func supportCodeAndTextArePinned(
		_ error: any LauncherDiagnosticError & Sendable,
		_ code: SupportCode?,
		_ description: String,
		_ diagnostic: String
	) {
		#expect(resolvedSupportCode(for: error) == code)
		#expect(error.errorDescription == description)
		#expect(error.diagnosticDescription == diagnostic)
	}

	/// Installation and runtime mappings never disagree on an error case,
	/// so the first non-nil code is the published code for that case.
	private func resolvedSupportCode(for error: any LauncherDiagnosticError) -> SupportCode? {
		InstallationController.supportCode(for: error)
			?? GameSessionController.supportCode(for: error)
			?? (error as? any SupportCodeProviding)?.supportCode
	}
}
