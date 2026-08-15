// SPDX-License-Identifier: MPL-2.0

import AppKit
import Foundation
import UniformTypeIdentifiers

extension LauncherViewModel {
	func chooseInstallDirectory() {
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
				selected.lastPathComponent == "Arknights_EN"
				? selected : selected.appending(path: "Arknights_EN", directoryHint: .isDirectory)
			preferences.setInstallDirectory(installDirectory)
			updateInstalledState()
		}
	}

	func locateExistingInstallation() {
		let panel = NSOpenPanel()
		panel.title = "Choose the folder containing Arknights.exe"
		panel.prompt = "Use Folder"
		panel.canChooseDirectories = true
		panel.canChooseFiles = false
		panel.allowsMultipleSelection = false
		panel.directoryURL = installDirectory
		if panel.runModal() == .OK, let selected = panel.url {
			installDirectory = selected
			preferences.setInstallDirectory(selected)
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

		do {
			try FileManager.default.createDirectory(
				at: paths.customArtwork.deletingLastPathComponent(),
				withIntermediateDirectories: true
			)
			if FileManager.default.fileExists(atPath: paths.customArtwork.path) {
				try FileManager.default.removeItem(at: paths.customArtwork)
			}
			try FileManager.default.copyItem(at: selected, to: paths.customArtwork)
			heroArtwork = NSImage(contentsOf: paths.customArtwork)
		} catch {
			show(error)
		}
	}

	func resetArtwork() {
		try? FileManager.default.removeItem(at: paths.customArtwork)
		guard !isDownloading else { return }
		activeRefreshID = nil
		refreshTask?.cancel()
		refreshTask = Task { [weak self] in
			await self?.refresh()
		}
	}

	func dismissNotice() {
		notice = nil
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
			])
		}
	}

	func revealInstallDirectory() {
		NSWorkspace.shared.activateFileViewerSelecting([installDirectory])
	}

	func uninstallGame() {
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
		installedVersion = state?.version
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
		notice = formattedNotice
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
