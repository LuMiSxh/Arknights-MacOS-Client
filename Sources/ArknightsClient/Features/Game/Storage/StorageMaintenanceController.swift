// SPDX-License-Identifier: MPL-2.0

import AppKit
import Foundation

/// Owns existing cache measurement and targeted cleanup operations.
@MainActor
final class StorageMaintenanceController {
	var onStorageOverviewChanged: (() -> Void)?

	private let lifecycle: LauncherLifecycleStore
	private let paths: AppPaths
	private let presetCatalog: PresetCatalogService
	private let log: LauncherLog
	private let regionProvider: @MainActor () -> GameRegion

	init(
		lifecycle: LauncherLifecycleStore,
		paths: AppPaths,
		presetCatalog: PresetCatalogService,
		log: LauncherLog,
		regionProvider: @escaping @MainActor () -> GameRegion = { .global }
	) {
		self.lifecycle = lifecycle
		self.paths = paths
		self.presetCatalog = presetCatalog
		self.log = log
		self.regionProvider = regionProvider
	}

	func clearGameCache() {
		guard lifecycle.activity == .idle else { return }
		let operationID = UUID()
		lifecycle.activity = .maintaining(.clearingCache)
		let winePrefix = paths.winePrefix(for: regionProvider())
		Task { [weak self] in
			guard let self else { return }
			do {
				try await Task.detached(priority: .utility) {
					try GameCacheCleaner.clear(winePrefix: winePrefix)
				}.value
				lifecycle.activity = .idle
				onStorageOverviewChanged?()
				await log.info("Shader and browser caches cleared")
			} catch {
				lifecycle.activity = .idle
				presentCacheFailure(error, id: operationID)
			}
		}
	}

	@discardableResult
	func retryCacheFailure(id: UUID) -> Bool {
		guard let failure = lifecycle.failure, failure.id == id else { return false }
		guard failure.context.operation == .cacheClearing else { return false }
		guard failure.context.region == nil, lifecycle.activity == .idle else { return false }
		guard failure.actions.contains(.retry) else { return false }
		guard lifecycle.consumeFailure(id: id) != nil else { return false }
		Task { [log] in
			await log.info("Recovery selected; action=retry operation=cache-clearing")
		}
		clearGameCache()
		return true
	}

	func clearPresetGalleryCache() {
		guard lifecycle.activity == .idle else { return }
		lifecycle.activity = .maintaining(.clearingCache)
		Task { [weak self] in
			guard let self else { return }
			do {
				try await presetCatalog.clearCaches()
				lifecycle.activity = .idle
				onStorageOverviewChanged?()
				await log.info("Preset gallery caches cleared")
			} catch {
				lifecycle.activity = .idle
				lifecycle.show(error)
			}
		}
	}

	func revealApplication() {
		NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
	}

	func revealLogs() {
		Task { [log, paths] in
			await log.prepare()
			NSWorkspace.shared.activateFileViewerSelecting([
				paths.launcherLogFile,
				paths.logFile,
				paths.wineLogFile(for: .china),
				paths.unityLogFile,
				paths.chromiumLogFile,
			])
		}
	}

	private func presentCacheFailure(_ error: any Error, id: UUID) {
		let message = launcherUserMessage(for: error)
		lifecycle.presentFailure(
			LauncherFailurePresentation(
				id: id,
				message: message,
				code: .basalt,
				context: SupportContext(operation: .cacheClearing, region: nil),
				actions: [.retry, .openTroubleshooting, .reportProblem]
			),
			diagnostic: launcherDiagnosticDescription(for: error)
		)
	}
}
