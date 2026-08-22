// SPDX-License-Identifier: MPL-2.0

import AppKit
import Foundation

extension LauncherViewModel {
	func chooseInstallDirectory() {
		#if DEBUG
			if isDeveloperMode { return }
		#endif
		guard state.activity == .idle else { return }
		let panel = NSOpenPanel()
		panel.title = "Choose where to install Arknights"
		panel.prompt = "Choose"
		panel.canChooseDirectories = true
		panel.canChooseFiles = false
		panel.canCreateDirectories = true
		panel.allowsMultipleSelection = false
		panel.directoryURL = installDirectory.deletingLastPathComponent()
		if panel.runModal() == .OK, let selected = panel.url {
			installDirectory =
				selected.lastPathComponent == region.gameTag
				? selected : selected.appending(path: region.gameTag, directoryHint: .isDirectory)
			preferences.setInstallDirectory(installDirectory, for: region)
			updateInstalledState()
		}
	}

	func locateExistingInstallation() {
		#if DEBUG
			if isDeveloperMode { return }
		#endif
		guard state.activity == .idle else { return }
		let panel = NSOpenPanel()
		panel.title = "Choose the folder containing Arknights.exe"
		panel.prompt = "Use Folder"
		panel.canChooseDirectories = true
		panel.canChooseFiles = false
		panel.allowsMultipleSelection = false
		panel.directoryURL = installDirectory
		if panel.runModal() == .OK, let selected = panel.url {
			installDirectory = selected
			preferences.setInstallDirectory(selected, for: region)
			updateInstalledState()
			setStatus(isInstalled ? .ready : .custom("Arknights.exe not found"))
		}
	}

	/// Deliberately leaves the selected region and install location alone: those point at
	/// real files on disk, not cosmetic preferences, and resetting them would make the
	/// launcher act as if an existing installation had vanished.
	func resetAllLauncherSettings() {
		guard canModifyLaunchOptions else { return }
		automaticallyChecksLauncherUpdates = true
		automaticallyChecksGameUpdates = true
		announcementsEnabled = true
		launchOptions = .default
		showsServerResetCountdown = false
		showsGameVersion = true
		playsLauncherMusic = true
		launcherMusicURL = AppConstants.Music.defaultLauncherMusicURL
		showsPlayingMusic = false
		launcherMusicVolume = 0.5
		usesDynamicTheme = true
		setStatus(.custom("Settings reset to default"))
		Task { [log] in await log.info("Launcher settings reset to default") }
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

	func revealInstallDirectory() {
		NSWorkspace.shared.activateFileViewerSelecting([installDirectory])
	}

	func clearCache() {
		guard state.activity == .idle else { return }
		state.activity = .maintaining(.clearingCache)
		let winePrefix = paths.winePrefix
		Task { [weak self] in
			guard let self else { return }
			do {
				let updatedCacheSizeText = try await Task.detached(priority: .utility) {
					try GameCacheCleaner.clear(winePrefix: winePrefix)
					return Self.gameCacheSizeText(winePrefix: winePrefix)
				}.value
				state.activity = .idle
				cacheSizeText = updatedCacheSizeText
				setStatus(.custom("Cache cleared"))
				await log.info("Shader and browser caches cleared")
			} catch {
				state.activity = .idle
				show(error)
			}
		}
	}

	func refreshGameCacheSize() {
		let winePrefix = paths.winePrefix
		Task { [weak self] in
			let text = await Task.detached(priority: .utility) {
				Self.gameCacheSizeText(winePrefix: winePrefix)
			}.value
			self?.cacheSizeText = text
		}
	}

	private nonisolated static func gameCacheSizeText(winePrefix: URL) -> String {
		ByteCountFormatter.string(
			fromByteCount: GameCacheCleaner.totalSize(winePrefix: winePrefix),
			countStyle: .file
		)
	}

	func clearPresetGalleryCache() {
		Task { [weak self] in
			guard let self else { return }
			do {
				try await presetCatalog.clearCaches()
				let cacheSizeText = await presetCatalog.cacheSizeText()
				setStatus(.custom("Asset gallery caches cleared"))
				presetGalleryCacheSizeText = cacheSizeText
				await log.info("Preset gallery caches cleared")
			} catch {
				show(error)
			}
		}
	}

	func refreshPresetGalleryCacheSize() {
		Task {
			let cacheSizeText = await presetCatalog.cacheSizeText()
			await MainActor.run {
				self.presetGalleryCacheSizeText = cacheSizeText
			}
		}
	}

	func uninstallGame() {
		#if DEBUG
			if isDeveloperMode { return }
		#endif
		guard state.activity == .idle else { return }
		guard FileManager.default.fileExists(atPath: installDirectory.path) else {
			updateInstalledState()
			return
		}
		let target = installDirectory
		state.activity = .maintaining(.uninstalling)
		setStatus(.movingToTrash)
		Task { [log] in await log.info("Game uninstall requested") }
		NSWorkspace.shared.recycle([target]) { [weak self] _, error in
			Task { @MainActor in
				guard let self else { return }
				if let error {
					self.state.activity = .idle
					self.show(error)
				} else {
					self.isInstalled = false
					self.hasPartialDownload = false
					self.installedVersion = nil
					self.isGameUpdateAvailable = false
					self.state.activity = .idle
					self.setStatus(.uninstalled)
				}
			}
		}
	}

	func updateInstalledState() {
		let hasExecutable = FileManager.default.fileExists(
			atPath: installDirectory.appending(path: "Arknights.exe").path
		)
		let state = loadInstalledState()
		isInstalled = hasExecutable && state != nil
		hasPartialDownload = !isInstalled && Self.containsPartialDownload(in: installDirectory)
		installedVersion = state?.version
	}

	private static func containsPartialDownload(in directory: URL) -> Bool {
		guard
			let enumerator = FileManager.default.enumerator(
				at: directory,
				includingPropertiesForKeys: nil,
				options: [.skipsPackageDescendants]
			)
		else { return false }
		for case let file as URL in enumerator where file.pathExtension == "part" {
			return true
		}
		return false
	}

	func updateGameAvailability() {
		guard isInstalled, let latest = configuration?.gameLatestVersion else {
			isGameUpdateAvailable = false
			return
		}
		isGameUpdateAvailable = installedVersion.map { $0 != latest } ?? true
	}

	func loadInstalledState() -> InstalledState? {
		let url = installDirectory.appending(path: AppConstants.Game.installedStateFileName)
		guard FileManager.default.fileExists(atPath: url.path) else { return nil }
		do {
			let data = try Data(contentsOf: url)
			let decoder = JSONDecoder()
			decoder.dateDecodingStrategy = .iso8601
			return try decoder.decode(InstalledState.self, from: data)
		} catch {
			Task { [log, region] in
				await log.error(
					"Installed state for \(region.displayName) is unreadable at \(url.path): \(error.localizedDescription)"
				)
			}
			return nil
		}
	}

	/// Cheap local existence check for a region that may not be the active one, so the main
	/// UI can offer a region switcher without triggering a network refresh for every region.
	func isRegionInstalled(_ candidate: GameRegion) -> Bool {
		guard candidate != region else { return isInstalled }
		let directory = preferences.installDirectory(
			for: candidate,
			default: paths.gameInstall(for: candidate)
		)
		let fileManager = FileManager.default
		guard fileManager.fileExists(atPath: directory.appending(path: "Arknights.exe").path)
		else { return false }
		return fileManager.fileExists(
			atPath: directory.appending(path: AppConstants.Game.installedStateFileName).path
		)
	}

	var installedRegions: [GameRegion] {
		GameRegion.allCases.filter(isRegionInstalled)
	}

	func presentNoticeIfNeeded(_ branding: LauncherBranding) {
		guard
			branding.noticePopOpen == true,
			let content = branding.noticeContent,
			content != presentedNoticeContent,
			let formattedNotice = LauncherNoticeFormatter.notice(fromHTML: content)
		else {
			return
		}
		presentedNoticeContent = content
		enqueuePopup(
			LauncherPopup(
				id: "yostar-notice-\(formattedNotice.id.uuidString)",
				title: "Notice",
				content: .attributed(formattedNotice.content),
				dismissTitle: "Done",
				actionTitle: nil,
				actionURL: nil
			)
		)
	}

	func isCurrentRefresh(_ refreshID: UUID) -> Bool {
		state.refresh.requestID == refreshID && !Task.isCancelled && !isDownloading
	}

	func show(_ error: Error, context: String? = nil) {
		let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
		state.presentation.failureMessage = message
		let diagnostic = launcherDiagnosticDescription(for: error)
		let logMessage = context.map { "\($0): \(diagnostic)" } ?? diagnostic
		Task { [log] in await log.error(logMessage) }
	}
}
