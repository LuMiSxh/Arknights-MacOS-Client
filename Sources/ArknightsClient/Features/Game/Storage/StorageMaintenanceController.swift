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
		guard let lease = lifecycle.begin(.maintaining(.clearingCache)) else { return }
		let operationID = UUID()
		let region = regionProvider()
		let winePrefix = paths.winePrefix(for: region)
		Task { [weak self, lifecycle = self.lifecycle] in
			guard let self else {
				lifecycle.end(lease)
				return
			}
			do {
				try await Task.detached(priority: .utility) {
					try GameCacheCleaner.clear(winePrefix: winePrefix)
				}.value
				lifecycle.end(lease)
				onStorageOverviewChanged?()
				log.info("Shader and browser caches cleared")
			} catch {
				lifecycle.end(lease)
				presentCacheFailure(error, id: operationID, region: region)
			}
		}
	}

	@discardableResult
	func retryCacheFailure(id: UUID) -> Bool {
		guard let failure = lifecycle.failure, failure.id == id else { return false }
		guard failure.context.operation == .cacheClearing else { return false }
		guard failure.context.region == regionProvider().supportRegion,
			lifecycle.activity == .idle
		else { return false }
		guard failure.actions.contains(.retry) else { return false }
		guard lifecycle.consumeFailure(id: id) != nil else { return false }
		log.info("Recovery selected; action=retry operation=cache-clearing")
		clearGameCache()
		return true
	}

	func clearPresetGalleryCache() {
		guard let lease = lifecycle.begin(.maintaining(.clearingCache)) else { return }
		Task { [weak self, lifecycle = self.lifecycle] in
			guard let self else {
				lifecycle.end(lease)
				return
			}
			do {
				try await presetCatalog.clearCaches()
				lifecycle.end(lease)
				onStorageOverviewChanged?()
				log.info("Preset gallery caches cleared")
			} catch {
				lifecycle.end(lease)
				lifecycle.show(error)
			}
		}
	}

	func revealApplication() {
		NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
	}

	nonisolated static func logURLs(for paths: AppPaths) -> [URL] {
		[
			paths.launcherLogFile,
			paths.publisherLogFile(for: .yostar),
			paths.publisherLogFile(for: .hypergryph),
			paths.publisherLogFile(for: .gryphline),
			paths.unityLogFile,
			paths.chromiumLogFile,
		]
	}

	func revealLogs() {
		Task { [log, paths] in
			await log.prepare()
			NSWorkspace.shared.activateFileViewerSelecting(Self.logURLs(for: paths))
		}
	}

	private func presentCacheFailure(_ error: any Error, id: UUID, region: GameRegion) {
		let message = launcherUserMessage(for: error)
		lifecycle.presentFailure(
			LauncherFailurePresentation(
				id: id,
				message: message,
				code: .basalt,
				context: SupportContext(
					operation: .cacheClearing,
					region: region.supportRegion
				),
				actions: [.retry, .openTroubleshooting, .reportProblem]
			),
			diagnostic: launcherDiagnosticDescription(for: error)
		)
	}
}
