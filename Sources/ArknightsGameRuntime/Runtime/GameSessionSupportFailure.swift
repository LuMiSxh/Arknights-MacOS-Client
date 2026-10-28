// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameInstallation
import ArknightsInfrastructure
import Foundation

extension GameSessionController {
	func presentRuntimeFailure(
		_ error: any Error,
		id: UUID,
		operation: SupportOperation,
		region: GameRegion,
		blocksGameLaunch: Bool? = nil
	) {
		lifecycle.presentFailure(
			error,
			id: id,
			code: Self.supportCode(for: error),
			context: SupportContext(operation: operation, region: region.supportRegion),
			canRepair: installation.isInstalled && operation != .runtimeStop,
			blocksGameLaunch: blocksGameLaunch
				?? (operation == .launch || operation == .runtimeDiscovery)
		)
	}

	@discardableResult
	package func retryRuntimeFailure(id: UUID) -> Bool {
		guard let failure = lifecycle.state.presentation.failure, failure.id == id else {
			return false
		}
		guard failure.actions.contains(.retry) else { return false }
		let activeRegion = session?.region
		switch failure.context.operation {
		case .prefixMigration, .prefixDeletion:
			guard failure.context.region == installation.region.supportRegion,
				lifecycle.activity == .idle
			else { return false }
		case .runtimeStop:
			guard activeRegion?.supportRegion == failure.context.region,
				lifecycle.activity.activeGameSessionID == failure.id,
				session?.isRuntimeStopInFlight != true
			else { return false }
		case .launch, .runtimeExit, .runtimeDiscovery:
			guard failure.context.region == installation.region.supportRegion else { return false }
			guard lifecycle.activity == .idle else { return false }
		default:
			return false
		}
		guard lifecycle.consumeFailure(id: id) != nil else { return false }
		log.info(
			"Recovery selected; action=retry operation=\(failure.context.operation.rawValue) region=\(installation.region.rawValue)"
		)
		switch failure.context.operation {
		case .runtimeStop:
			guard let activeRegion else { return false }
			retryFailedRuntimeStop(sessionID: id, region: activeRegion)
		case .prefixMigration:
			forcePrefixMigration()
		case .prefixDeletion:
			deleteWinePrefix()
		default:
			launch()
		}
		return true
	}

	static func supportCode(for error: any Error) -> SupportCode? {
		if error is WineRuntimeDiscoveryError {
			return .bundledRuntimeDamaged
		}
		return switch error {
		case GameRuntimeError.wineRuntimeMissing:
			.bundledRuntimeDamaged
		case GameRuntimeError.rosettaMissing:
			.rosettaMissing
		case GameRuntimeError.rosettaDisabledByGameTestMode,
			GameRuntimeError.intelTranslationUnavailable,
			GameRuntimeError.intelTranslationUnsupported:
			.intelTranslationBlocked
		case GameRuntimeError.runtimeConfiguration:
			.runtimeSetupFailed
		case GameRuntimeError.gameCompatibility, is GameShimRollbackError:
			.compatibilitySetupFailed
		case GameRuntimeError.runtimeWindowTimeout:
			.gameWindowTimeout
		case GameRuntimeError.runtimeExited:
			.gameClosedUnexpectedly
		case GameRuntimeError.bilibiliControllerFailed:
			.bilibiliLoginUnavailable
		case GameRuntimeError.gameNotInstalled:
			.gameFilesMissing
		case InstallerError.cannotCreateFile:
			.installFolderUnusable
		case is BoundedFileReadError, is CocoaError, is POSIXError:
			.runtimeSetupFailed
		default:
			nil
		}
	}

}
