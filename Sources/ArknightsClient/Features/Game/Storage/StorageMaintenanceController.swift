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

	init(
		lifecycle: LauncherLifecycleStore,
		paths: AppPaths,
		presetCatalog: PresetCatalogService,
		log: LauncherLog
	) {
		self.lifecycle = lifecycle
		self.paths = paths
		self.presetCatalog = presetCatalog
		self.log = log
	}

	func clearGameCache() {
		guard lifecycle.activity == .idle else { return }
		lifecycle.activity = .maintaining(.clearingCache)
		let winePrefix = paths.winePrefix
		Task { [weak self] in
			guard let self else { return }
			do {
				try await Task.detached(priority: .utility) {
					try GameCacheCleaner.clear(winePrefix: winePrefix)
				}.value
				lifecycle.activity = .idle
				lifecycle.setStatus(.custom(L10n.string(.Launcher.launcherStatusCacheCleared)))
				onStorageOverviewChanged?()
				await log.info("Shader and browser caches cleared")
			} catch {
				lifecycle.activity = .idle
				lifecycle.show(error)
			}
		}
	}

	func clearPresetGalleryCache() {
		guard lifecycle.activity == .idle else { return }
		lifecycle.activity = .maintaining(.clearingCache)
		Task { [weak self] in
			guard let self else { return }
			do {
				try await presetCatalog.clearCaches()
				lifecycle.activity = .idle
				lifecycle.setStatus(
					.custom(L10n.string(.Launcher.launcherStatusGalleryCacheCleared)))
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
				paths.unityLogFile,
				paths.chromiumLogFile,
			])
		}
	}
}
