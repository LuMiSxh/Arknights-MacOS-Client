// SPDX-License-Identifier: MPL-2.0

import AppKit
import Foundation

extension LauncherViewModel {
	func performRecoveryAction(
		_ action: RecoveryAction,
		failureID: UUID
	) -> RecoveryActionDisposition {
		guard let failure = lifecycle.failure, failure.id == failureID else {
			logRecovery(action: action, result: "ignored-stale")
			return .ignored
		}
		guard failure.actions.contains(action) else {
			logRecovery(action: action, result: "ignored-not-allowed")
			return .ignored
		}
		#if DEBUG
			if isDeveloperMode, action == .retry {
				guard lifecycle.consumeFailure(id: failureID) != nil else { return .ignored }
				logRecovery(action: action, result: "simulated")
				applyDeveloperScenario(.launching)
				return .completed
			}
		#endif

		switch action {
		case .retry:
			let started: Bool
			switch failure.context.operation {
			case .install, .update, .repair:
				started = installation.retryInstallationFailure(id: failureID)
			case .uninstall:
				started = installation.retryUninstallFailure(id: failureID)
			case .cacheClearing:
				started = storage.retryCacheFailure(id: failureID)
			case .launch, .runtimeDiscovery, .prefixMigration, .prefixDeletion,
				.runtimeStop, .runtimeExit:
				started = gameSession.retryRuntimeFailure(id: failureID)
			case .configurationRefresh:
				started = refreshController.retryConfigurationFailure(id: failureID)
			case .rosettaInstallation:
				started = intelTranslation.retryRosettaFailure(id: failureID)
			case .launcher:
				logRecovery(action: action, result: "ignored-no-retry-route")
				return .ignored
			}
			if !started {
				logRecovery(action: action, result: "ignored-ineligible")
				return .ignored
			}
			return .completed
		case .showLogs:
			storage.revealLogs()
			logRecovery(action: action, result: "opened")
			return .completed
		case .openTroubleshooting:
			guard let code = failure.code else {
				logRecovery(action: action, result: "ignored-no-code")
				return .ignored
			}
			NSWorkspace.shared.open(code.troubleshootingURL)
			logRecovery(action: action, result: "opened")
			return .completed
		case .reportProblem:
			NSWorkspace.shared.open(
				IssueReportURL.build(code: failure.code, context: failure.context)
			)
			logRecovery(action: action, result: "opened")
			return .completed
		case .repair:
			return .repairConfirmationRequired
		}
	}

	func confirmRepair(failureID: UUID) {
		guard let failure = lifecycle.failure, failure.id == failureID else {
			logRecovery(action: .repair, result: "ignored-stale")
			return
		}
		guard failure.actions.contains(.repair) else {
			logRecovery(action: .repair, result: "ignored-not-allowed")
			return
		}
		guard failure.context.region == installation.region.supportRegion else {
			logRecovery(action: .repair, result: "ignored-region-changed")
			return
		}
		guard installation.isInstalled, installation.canInstall else {
			logRecovery(action: .repair, result: "ignored-ineligible")
			return
		}
		guard lifecycle.consumeFailure(id: failureID) != nil else {
			logRecovery(action: .repair, result: "ignored-stale")
			return
		}
		#if DEBUG
			if isDeveloperMode {
				logRecovery(action: .repair, result: "simulated")
				applyDeveloperScenario(.downloading)
				return
			}
		#endif
		logRecovery(action: .repair, result: "started")
		installation.repairGame()
	}

	private func logRecovery(action: RecoveryAction, result: String) {
		Task { [log] in
			await log.info("Recovery selected; action=\(action.rawValue) result=\(result)")
		}
	}
}
