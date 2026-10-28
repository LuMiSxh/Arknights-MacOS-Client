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
			code: operation == .uninstall
				? .localFileFailed : Self.supportCode(for: presentedError),
			context: SupportContext(operation: operation, region: region.supportRegion),
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
		case let diagnosed as DiagnosedLauncherError:
			supportCode(for: diagnosed.underlying)
		case let contextual as ContextualLauncherError:
			contextual.supportCode ?? .serviceError
		case InstallerError.invalidManifestPath,
			InstallerError.duplicateManifestPath,
			InstallerError.conflictingManifestPaths:
			.manifestUnsafe
		case InstallerError.symbolicLinkInInstallPath,
			InstallerError.cannotCreateFile,
			InstallerError.unsafeInstallerTemporaryFile,
			is DiskCapacityError:
			.installFolderUnusable
		case InstallerError.installDirectoryInUse:
			.installationBusy
		case InstallerError.insufficientDiskSpace:
			.insufficientDiskSpace
		case LauncherError.invalidResponse,
			CustomizationError.invalidRemoteAsset,
			LauncherError.remoteContentTooLarge:
			.remoteContentInvalid
		case InstallerError.invalidDownloadResponse,
			InstallerError.downloadedSizeMismatch,
			InstallerError.checksumMismatch:
			.downloadDamaged
		case is HTTPTransportError, is URLError:
			.networkUnavailable
		case LauncherError.server, InstallerError.missingConfiguration:
			.serviceError
		case is GameCompatibilityError, is GameShimRollbackError:
			.compatibilitySetupFailed
		case is CocoaError, is POSIXError:
			.localFileFailed
		default:
			nil
		}
	}

	private static func isMissingConfiguration(_ error: any Error) -> Bool {
		if case InstallerError.missingConfiguration = error { return true }
		return false
	}
}
