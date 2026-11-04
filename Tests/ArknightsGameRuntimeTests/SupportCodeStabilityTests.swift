// SPDX-License-Identifier: MPL-2.0

import ArknightsCustomization
import Foundation
import Testing

@testable import ArknightsCore
@testable import ArknightsGameInstallation
@testable import ArknightsGameRuntime

// Edit only this table when a `LauncherError` case changes. Each row pins the
// support code, `errorDescription`, and `diagnosticDescription` of one case.
// Edit only this table when a `LauncherError` case changes. Each row pins the
// support code of one case. Message text is copy and is not pinned here.
// Edit only this table when a `LauncherError` case changes. Each row pins the
// support code of one case. Message text is copy and is not pinned here.
private let supportCodeStabilityCases: [(any LauncherDiagnosticError & Sendable, SupportCode?)] = [
	(CaptureError.permissionDenied, .screenCapturePermissionDenied),
	(CaptureError.noGameWindow, .screenCaptureWindowMissing),
	(CaptureError.saveFailed("test"), .localFileFailed),
	(LauncherError.invalidResponse, .remoteContentInvalid),
	(LauncherError.server(code: 500, message: "test"), .serviceError),
	(InstallerError.invalidManifestPath("../test"), .manifestUnsafe),
	(InstallerError.duplicateManifestPath("a"), .manifestUnsafe),
	(InstallerError.conflictingManifestPaths("a", "b"), .manifestUnsafe),
	(
		InstallerError.symbolicLinkInInstallPath(URL(filePath: "/tmp/test")),
		.installFolderUnusable
	),
	(
		InstallerError.invalidDownloadResponse(status: 404, path: "game.bin"),
		.downloadDamaged
	),
	(
		LauncherError.remoteContentTooLarge(
			URL(string: "https://cdn.example/game.bin")!, maximumBytes: 1_000_000),
		.remoteContentInvalid
	),
	(
		CustomizationError.invalidRemoteAsset(URL(string: "http://cdn.example/a")!),
		.remoteContentInvalid
	),
	(
		CustomizationError.invalidPresetImage(URL(string: "https://cdn.example/p.png")!),
		.artworkImageInvalid
	),
	(CustomizationError.invalidCustomImage(URL(filePath: "/tmp/c.txt")), .artworkImageInvalid),
	(CustomizationError.cannotEncodeAppIcon, .appIconFailed),
	(CustomizationError.cannotSetAppIcon, .appIconFailed),
	(
		InstallerError.downloadedSizeMismatch(path: "a.bin", expected: 10, actual: 5),
		.downloadDamaged
	),
	(
		InstallerError.checksumMismatch(path: "a.bin", expected: "x", actual: "y"),
		.downloadDamaged
	),
	(InstallerError.cannotCreateFile(URL(filePath: "/tmp/f")), .installFolderUnusable),
	(
		InstallerError.unsafeInstallerTemporaryFile(URL(filePath: "/tmp/t")),
		.installFolderUnusable
	),
	(InstallerError.installDirectoryInUse(URL(filePath: "/tmp/i")), .installationBusy),
	(InstallerError.missingConfiguration, .serviceError),
	(GameRuntimeError.gameNotInstalled(URL(filePath: "/tmp/g")), .gameFilesMissing),
	(
		InstallerError.insufficientDiskSpace(required: 2_000_000_000, available: 1_000_000),
		.insufficientDiskSpace
	),
	(GameRuntimeError.wineRuntimeMissing, .bundledRuntimeDamaged),
	(GameRuntimeError.rosettaMissing, .rosettaMissing),
	(GameRuntimeError.rosettaDisabledByGameTestMode, .intelTranslationBlocked),
	(GameRuntimeError.intelTranslationUnavailable, .intelTranslationBlocked),
	(GameRuntimeError.intelTranslationUnsupported, .intelTranslationBlocked),
	(GameRuntimeError.runtimeWindowTimeout, .gameWindowTimeout),
	(GameRuntimeError.runtimeConfiguration("cfg"), .runtimeSetupFailed),
	(GameRuntimeError.gameCompatibility("shim"), .compatibilitySetupFailed),
	(
		GameRuntimeError.runtimeExited(status: 1, log: URL(filePath: "/tmp/wine.log")),
		.gameClosedUnexpectedly
	),
	(
		GameRuntimeError.bilibiliControllerFailed("spawn denied"),
		.bilibiliLoginUnavailable
	),
	(CustomizationError.presetServiceFailed(status: 503), .serviceError),
	(CustomizationError.presetNetworkFailed(detail: "offline"), .networkUnavailable),
	(LauncherError.storageMigrationFailed("disk"), .dataMigrationFailed),
	(DiagnosticsError(detail: "ditto exited with status 1"), .localFileFailed),
]

@MainActor
struct SupportCodeStabilityTests {
	@Test(arguments: supportCodeStabilityCases)
	func supportCodeIsPinned(
		_ error: any LauncherDiagnosticError & Sendable,
		_ code: SupportCode?
	) {
		#expect(resolvedSupportCode(for: error) == code)
	}

	/// Installation and runtime may both handle one case, and they must agree on its code.
	/// The first non-nil code is the published code for that case.
	private func resolvedSupportCode(for error: any LauncherDiagnosticError) -> SupportCode? {
		InstallationController.supportCode(for: error)
			?? GameSessionController.supportCode(for: error)
			?? (error as? any SupportCodeProviding)?.supportCode
	}
}
