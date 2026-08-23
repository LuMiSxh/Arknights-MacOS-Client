// SPDX-License-Identifier: MPL-2.0

import AppKit
import Foundation

extension InstallationController {
	func chooseInstallDirectory() {
		guard lifecycle.activity == .idle else { return }
		let panel = NSOpenPanel()
		panel.title = L10n.string(LauncherStrings.pickerInstallDirectory)
		panel.prompt = L10n.string(LauncherStrings.pickerChoose)
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
		guard lifecycle.activity == .idle else { return }
		let panel = NSOpenPanel()
		panel.title = L10n.string(LauncherStrings.pickerLocateInstallation)
		panel.prompt = L10n.string(LauncherStrings.pickerUseFolder)
		panel.canChooseDirectories = true
		panel.canChooseFiles = false
		panel.allowsMultipleSelection = false
		panel.directoryURL = installDirectory
		if panel.runModal() == .OK, let selected = panel.url {
			installDirectory = selected
			preferences.setInstallDirectory(selected, for: region)
			updateInstalledState()
			lifecycle.setStatus(
				isInstalled
					? .ready
					: .custom(L10n.string(.Launcher.launcherStatusGameNotFound))
			)
		}
	}

	func revealInstallDirectory() {
		NSWorkspace.shared.activateFileViewerSelecting([installDirectory])
	}

	func uninstallGame() {
		guard lifecycle.activity == .idle else { return }
		guard FileManager.default.fileExists(atPath: installDirectory.path) else {
			updateInstalledState()
			return
		}
		let target = installDirectory
		lifecycle.activity = .maintaining(.uninstalling)
		lifecycle.setStatus(.movingToTrash)
		Task { [log] in await log.info("Game uninstall requested") }
		NSWorkspace.shared.recycle([target]) { [weak self] _, error in
			Task { @MainActor in
				guard let self else { return }
				self.lifecycle.activity = .idle
				if let error {
					self.lifecycle.show(error)
				} else {
					self.isInstalled = false
					self.hasPartialDownload = false
					self.installedVersion = nil
					self.isGameUpdateAvailable = false
					self.lifecycle.setStatus(.uninstalled)
				}
			}
		}
	}
}
