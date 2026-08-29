// SPDX-License-Identifier: MPL-2.0

import Foundation

extension GameSessionController {
	func presentRuntimeFailure(
		_ error: any Error,
		id: UUID,
		operation: SupportOperation,
		region: GameRegion,
		blocksGameLaunch: Bool? = nil
	) {
		let code = Self.supportCode(for: error, operation: operation)
		let actions = Self.recoveryActions(
			for: code,
			isInstalled: installation.isInstalled,
			operation: operation
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
				blocksGameLaunch: blocksGameLaunch
					?? (operation == .launch || operation == .runtimeDiscovery)
			),
			diagnostic: launcherDiagnosticDescription(for: error)
		)
	}

	@discardableResult
	func retryRuntimeFailure(id: UUID) -> Bool {
		guard let failure = lifecycle.failure, failure.id == id else { return false }
		guard failure.actions.contains(.retry) else { return false }
		switch failure.context.operation {
		case .prefixMigration, .prefixDeletion:
			guard failure.context.region == nil, lifecycle.activity == .idle else { return false }
		case .runtimeStop:
			guard failure.context.region == installation.region.supportRegion else { return false }
			guard
				case .runningGame(let sessionID, _) = lifecycle.activity,
				sessionID == failure.id
			else { return false }
		case .launch, .runtimeExit, .runtimeDiscovery:
			guard failure.context.region == installation.region.supportRegion else { return false }
			guard lifecycle.activity == .idle else { return false }
		default:
			return false
		}
		guard lifecycle.consumeFailure(id: id) != nil else { return false }
		Task { [log] in
			await log.info(
				"Recovery selected; action=retry operation=\(failure.context.operation.rawValue) region=\(installation.region.rawValue)"
			)
		}
		switch failure.context.operation {
		case .runtimeStop:
			stopGame()
		case .prefixMigration:
			forcePrefixMigration()
		case .prefixDeletion:
			deleteWinePrefix()
		default:
			launch()
		}
		return true
	}

	static func supportCode(
		for error: any Error,
		operation: SupportOperation
	) -> SupportCode? {
		if error is WineRuntimeDiscoveryError {
			return .whelk
		}
		return switch error {
		case LauncherError.wineRuntimeMissing:
			.whelk
		case LauncherError.rosettaMissing,
			LauncherError.rosettaDisabledByGameTestMode,
			LauncherError.intelTranslationUnavailable,
			LauncherError.intelTranslationUnsupported:
			.limpet
		case LauncherError.runtimeConfiguration:
			.sepia
		case LauncherError.gameCompatibility, is GameShimRollbackError:
			.anemone
		case LauncherError.runtimeWindowTimeout:
			.narwhal
		case LauncherError.runtimeExited:
			.crux
		case LauncherError.gameNotInstalled:
			.pebble
		case LauncherError.cannotCreateFile:
			.basalt
		case is CocoaError, is POSIXError:
			.sepia
		default:
			nil
		}
	}

	static func recoveryActions(
		for code: SupportCode?,
		isInstalled: Bool,
		operation: SupportOperation
	) -> [RecoveryAction] {
		var actions: [RecoveryAction] = [.retry, .showLogs]
		if code != nil { actions.append(.openTroubleshooting) }
		if code == .pebble || code == .anemone || code == .narwhal || code == .crux,
			isInstalled, operation != .runtimeStop
		{
			actions.append(.repair)
		}
		actions.append(.reportProblem)
		return actions
	}
}
