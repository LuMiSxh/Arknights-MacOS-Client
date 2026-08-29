// SPDX-License-Identifier: MPL-2.0

import Foundation

extension InstallationController {
	func presentInstallationFailure(
		_ error: any Error,
		id: UUID,
		operation: SupportOperation,
		region: GameRegion
	) {
		let code: SupportCode? =
			operation == .uninstall ? .basalt : Self.supportCode(for: error)
		let actions = Self.recoveryActions(
			for: code,
			isInstalled: isInstalled,
			operation: operation,
			allowsRetry: !Self.isMissingConfiguration(error)
		)
		let message =
			(error as? any LocalizedError)?.errorDescription
			?? error.localizedDescription
		lifecycle.presentFailure(
			LauncherFailurePresentation(
				id: id,
				message: message,
				code: code,
				context: SupportContext(
					operation: operation,
					region: region.supportRegion
				),
				actions: actions,
				blocksGameLaunch: operation == .install || operation == .update
					|| operation == .repair
			),
			diagnostic: launcherDiagnosticDescription(for: error)
		)
	}

	static func supportCode(for error: any Error) -> SupportCode? {
		switch error {
		case LauncherError.invalidManifestPath,
			LauncherError.duplicateManifestPath,
			LauncherError.conflictingManifestPaths:
			.gabbro
		case LauncherError.symbolicLinkInInstallPath,
			LauncherError.cannotCreateFile,
			LauncherError.unsafeInstallerTemporaryFile:
			.basalt
		case LauncherError.insufficientDiskSpace:
			.scree
		case LauncherError.invalidResponse,
			LauncherError.invalidDownloadResponse,
			LauncherError.downloadedSizeMismatch,
			LauncherError.checksumMismatch,
			is URLError:
			.pebble
		case LauncherError.server,
			LauncherError.missingConfiguration,
			is ContextualLauncherError:
			.virga
		case LauncherError.gameCompatibility, is GameShimRollbackError:
			.anemone
		case is CocoaError, is POSIXError:
			.basalt
		default:
			nil
		}
	}

	static func recoveryActions(
		for code: SupportCode?,
		isInstalled: Bool,
		operation: SupportOperation,
		allowsRetry: Bool = true
	) -> [RecoveryAction] {
		var actions: [RecoveryAction] = []
		if allowsRetry { actions.append(.retry) }
		if code != nil { actions.append(.openTroubleshooting) }
		if code == .pebble || code == .anemone, isInstalled, operation != .repair {
			actions.append(.repair)
		}
		actions.append(.reportProblem)
		return actions
	}

	private static func isMissingConfiguration(_ error: any Error) -> Bool {
		if case LauncherError.missingConfiguration = error { return true }
		return false
	}
}
