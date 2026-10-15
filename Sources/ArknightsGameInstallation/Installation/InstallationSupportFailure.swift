// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsCustomization
import ArknightsInfrastructure
import Foundation

extension InstallationController {
	func presentInstallationFailure(
		_ error: any Error,
		id: UUID,
		operation: SupportOperation,
		region: GameRegion
	) {
		let presentedError = Self.mapTransportError(error)
		lifecycle.presentFailure(
			presentedError,
			id: id,
			code: operation == .uninstall ? .basalt : Self.supportCode(for: presentedError),
			context: SupportContext(operation: operation, region: region.supportRegion),
			repairableCodes: [.pebble, .anemone],
			canRepair: isInstalled && operation != .repair,
			allowsRetry: !Self.isMissingConfiguration(error),
			blocksGameLaunch: operation == .install || operation == .update
				|| operation == .repair
		)
	}

	private static func mapTransportError(_ error: any Error) -> any Error {
		guard let transportError = error as? HTTPTransportError else { return error }
		return GameInstaller.launcherError(for: transportError)
	}

	static func supportCode(for error: any Error) -> SupportCode? {
		switch error {
		case InstallerError.invalidManifestPath,
			InstallerError.duplicateManifestPath,
			InstallerError.conflictingManifestPaths:
			.gabbro
		case InstallerError.symbolicLinkInInstallPath,
			InstallerError.cannotCreateFile,
			InstallerError.unsafeInstallerTemporaryFile,
			InstallerError.installDirectoryInUse:
			.basalt
		case InstallerError.insufficientDiskSpace:
			.scree
		case is DiskCapacityError:
			.basalt
		case LauncherError.invalidResponse,
			CustomizationError.invalidRemoteAsset,
			LauncherError.remoteContentTooLarge,
			InstallerError.invalidDownloadResponse,
			InstallerError.downloadedSizeMismatch,
			InstallerError.checksumMismatch,
			is HTTPTransportError,
			is URLError:
			.pebble
		case LauncherError.server,
			InstallerError.missingConfiguration,
			is ContextualLauncherError:
			.virga
		case is GameCompatibilityError, is GameShimRollbackError:
			.anemone
		case is CocoaError, is POSIXError:
			.basalt
		default:
			nil
		}
	}

	private static func isMissingConfiguration(_ error: any Error) -> Bool {
		if case InstallerError.missingConfiguration = error { return true }
		return false
	}
}
