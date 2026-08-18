// SPDX-License-Identifier: MPL-2.0

import AppKit
import Foundation
import UniformTypeIdentifiers

extension LauncherViewModel {
	func chooseInstallDirectory() {
		#if DEBUG
			if isDeveloperMode { return }
		#endif
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
			activityMessage = isInstalled ? "Ready" : "Arknights.exe not found"
		}
	}

	func chooseCustomArtwork() {
		let panel = NSOpenPanel()
		panel.title = "Choose launcher artwork"
		panel.prompt = "Choose"
		panel.allowedContentTypes = [.image]
		panel.canChooseDirectories = false
		panel.canChooseFiles = true
		panel.allowsMultipleSelection = false
		guard panel.runModal() == .OK, let selected = panel.url else { return }
		applyCustomArtwork(from: selected)
	}

	func applyCustomArtwork(from url: URL) {
		do {
			try FileManager.default.createDirectory(
				at: paths.customArtwork.deletingLastPathComponent(),
				withIntermediateDirectories: true
			)
			if FileManager.default.fileExists(atPath: paths.customArtwork.path) {
				try FileManager.default.removeItem(at: paths.customArtwork)
			}
			try FileManager.default.copyItem(at: url, to: paths.customArtwork)
			heroArtwork = NSImage(contentsOf: paths.customArtwork)
		} catch {
			show(error)
		}
	}

	func resetArtwork() {
		#if DEBUG
			if isDeveloperMode { return }
		#endif
		try? FileManager.default.removeItem(at: paths.customArtwork)
		guard !isDownloading else { return }
		activeRefreshID = nil
		refreshTask?.cancel()
		refreshTask = Task { [weak self] in
			await self?.refresh()
		}
	}

	/// Persists via `NSWorkspace.setIcon`, a Finder extended attribute on the app bundle
	/// untouched by code signing, plus our own copy so the Dock icon can be reapplied on
	/// the next launch (`NSApp.applicationIconImage` itself resets every launch).
	func chooseCustomAppIcon() {
		let panel = NSOpenPanel()
		panel.title = "Choose an app icon"
		panel.prompt = "Choose"
		panel.allowedContentTypes = [.image]
		panel.canChooseDirectories = false
		panel.canChooseFiles = true
		panel.allowsMultipleSelection = false
		guard panel.runModal() == .OK, let selected = panel.url else { return }
		applyCustomAppIcon(from: selected)
	}

	func applyCustomAppIcon(from url: URL) {
		guard let image = NSImage(contentsOf: url) else { return }
		do {
			try FileManager.default.createDirectory(
				at: paths.customAppIcon.deletingLastPathComponent(),
				withIntermediateDirectories: true
			)
			if FileManager.default.fileExists(atPath: paths.customAppIcon.path) {
				try FileManager.default.removeItem(at: paths.customAppIcon)
			}
			try FileManager.default.copyItem(at: url, to: paths.customAppIcon)
			NSWorkspace.shared.setIcon(image, forFile: Bundle.main.bundlePath, options: [])
			NSApp.applicationIconImage = image
		} catch {
			show(error)
		}
	}

	func resetAppIcon() {
		try? FileManager.default.removeItem(at: paths.customAppIcon)
		NSWorkspace.shared.setIcon(nil, forFile: Bundle.main.bundlePath, options: [])
		NSApp.applicationIconImage = nil
	}

	@discardableResult
	func loadCustomAppIcon() -> Bool {
		guard let image = NSImage(contentsOf: paths.customAppIcon) else { return false }
		NSApp.applicationIconImage = image
		return true
	}

	/// Deliberately leaves the selected region and install location alone: those point at
	/// real files on disk, not cosmetic preferences, and resetting them would make the
	/// launcher act as if an existing installation had vanished.
	func resetAllLauncherSettings() {
		automaticallyChecksLauncherUpdates = true
		automaticallyChecksGameUpdates = true
		announcementsEnabled = true
		launchOptions = .default
		showsServerResetCountdown = false
		showsGameVersion = true
		activityMessage = "Settings reset to default"
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

	var cacheSizeText: String {
		ByteCountFormatter.string(
			fromByteCount: GameCacheCleaner.totalSize(winePrefix: paths.winePrefix),
			countStyle: .file
		)
	}

	func clearCache() {
		do {
			try GameCacheCleaner.clear(winePrefix: paths.winePrefix)
			activityMessage = "Cache cleared"
			Task { [log] in await log.info("Shader and browser caches cleared") }
		} catch {
			show(error)
		}
	}

	func uninstallGame() {
		#if DEBUG
			if isDeveloperMode { return }
		#endif
		guard !isDownloading else { return }
		guard FileManager.default.fileExists(atPath: installDirectory.path) else {
			updateInstalledState()
			return
		}
		let target = installDirectory
		activityMessage = "Moving to Trash…"
		Task { [log] in await log.info("Game uninstall requested") }
		NSWorkspace.shared.recycle([target]) { [weak self] _, error in
			Task { @MainActor in
				guard let self else { return }
				if let error {
					self.show(error)
				} else {
					self.isInstalled = false
					self.hasPartialDownload = false
					self.installedVersion = nil
					self.isGameUpdateAvailable = false
					self.phase = .ready
					self.activityMessage = "Uninstalled"
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
		let url = installDirectory.appending(path: ".arknights-client-state.json")
		guard let data = try? Data(contentsOf: url) else { return nil }
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .iso8601
		return try? decoder.decode(InstalledState.self, from: data)
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
			atPath: directory.appending(path: ".arknights-client-state.json").path
		)
	}

	var installedRegions: [GameRegion] {
		GameRegion.allCases.filter(isRegionInstalled)
	}

	func loadCustomArtwork() -> Bool {
		guard let image = NSImage(contentsOf: paths.customArtwork) else { return false }
		heroArtwork = image
		return true
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
		activeRefreshID == refreshID && !Task.isCancelled && !isDownloading
	}

	func show(_ error: Error) {
		let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
		phase = .failed(message)
		activityMessage = message
		Task { [log] in await log.error(message) }
	}
}
