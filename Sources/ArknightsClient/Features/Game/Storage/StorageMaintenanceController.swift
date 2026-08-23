// SPDX-License-Identifier: MPL-2.0

import AppKit
import Foundation
import Observation

/// Owns existing cache measurement and targeted cleanup operations.
@MainActor
@Observable
final class StorageMaintenanceController {
	var gameCacheSizeText: String
	var presetGalleryCacheSizeText: String

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
		let calculatingText = L10n.string(SettingsStrings.calculating)
		gameCacheSizeText = calculatingText
		presetGalleryCacheSizeText = calculatingText
		self.lifecycle = lifecycle
		self.paths = paths
		self.presetCatalog = presetCatalog
		self.log = log
	}

	func refreshSizes() {
		refreshGameCacheSize()
		refreshPresetGalleryCacheSize()
	}

	func clearGameCache() {
		guard lifecycle.activity == .idle else { return }
		lifecycle.activity = .maintaining(.clearingCache)
		let winePrefix = paths.winePrefix
		Task { [weak self] in
			guard let self else { return }
			do {
				let updatedCacheSizeText = try await Task.detached(priority: .utility) {
					try GameCacheCleaner.clear(winePrefix: winePrefix)
					return Self.gameCacheSizeText(winePrefix: winePrefix)
				}.value
				lifecycle.activity = .idle
				gameCacheSizeText = updatedCacheSizeText
				lifecycle.setStatus(.custom(L10n.string(.Launcher.launcherStatusCacheCleared)))
				await log.info("Shader and browser caches cleared")
			} catch {
				lifecycle.activity = .idle
				lifecycle.show(error)
			}
		}
	}

	func refreshGameCacheSize() {
		let winePrefix = paths.winePrefix
		Task { [weak self] in
			let text = await Task.detached(priority: .utility) {
				Self.gameCacheSizeText(winePrefix: winePrefix)
			}.value
			self?.gameCacheSizeText = text
		}
	}

	func clearPresetGalleryCache() {
		Task { [weak self] in
			guard let self else { return }
			do {
				try await presetCatalog.clearCaches()
				presetGalleryCacheSizeText = await presetCatalog.cacheSizeText()
				lifecycle.setStatus(
					.custom(L10n.string(.Launcher.launcherStatusGalleryCacheCleared)))
				await log.info("Preset gallery caches cleared")
			} catch {
				lifecycle.show(error)
			}
		}
	}

	func refreshPresetGalleryCacheSize() {
		Task { [weak self] in
			guard let self else { return }
			presetGalleryCacheSizeText = await presetCatalog.cacheSizeText()
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

	private nonisolated static func gameCacheSizeText(winePrefix: URL) -> String {
		ByteCountFormatter.string(
			fromByteCount: GameCacheCleaner.totalSize(winePrefix: winePrefix),
			countStyle: .file
		)
	}
}
