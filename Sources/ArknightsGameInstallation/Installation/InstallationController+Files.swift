// SPDX-License-Identifier: MPL-2.0

import AppKit
import Foundation

extension InstallationController {
	package func chooseInstallDirectory() {
		guard lifecycle.activity == .idle else { return }
		let panel = NSOpenPanel()
		panel.title = InstallationStrings.pickerInstallDirectory
		panel.prompt = InstallationStrings.pickerChoose
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

	package func locateExistingInstallation() {
		guard lifecycle.activity == .idle else { return }
		let panel = NSOpenPanel()
		panel.title = InstallationStrings.pickerLocateInstallation
		panel.prompt = InstallationStrings.pickerUseFolder
		panel.canChooseDirectories = true
		panel.canChooseFiles = false
		panel.allowsMultipleSelection = false
		panel.directoryURL = installDirectory
		if panel.runModal() == .OK, let selected = panel.url {
			installDirectory = selected
			preferences.setInstallDirectory(selected, for: region)
			let requestedRegion = region
			let refreshTask = updateInstalledState()
			Task { [weak self] in
				await refreshTask.value
				guard
					let self,
					self.region == requestedRegion,
					self.installDirectory == selected,
					self.lifecycle.activity == .idle
				else { return }
				self.lifecycle.setStatus(
					self.isInstalled
						? .ready
						: .gameExecutableNotFound
				)
			}
		}
	}

	package func revealInstallDirectory() {
		NSWorkspace.shared.activateFileViewerSelecting([installDirectory])
	}

	package func uninstallGame() {
		guard canUninstallGame else { return }
		guard FileManager.default.fileExists(atPath: installDirectory.path) else {
			updateInstalledState()
			return
		}
		let operationID = UUID()
		let requestedRegion = region
		guard let lease = lifecycle.begin(.maintaining(.uninstalling)) else { return }
		lifecycle.setStatus(.movingToTrash)
		log.info("Game uninstall requested")
		NSWorkspace.shared.recycle([installDirectory]) { [weak self] _, error in
			Task { @MainActor in
				guard let self else { return }
				self.lifecycle.end(lease)
				if let error {
					self.presentInstallationFailure(
						error,
						id: operationID,
						operation: .uninstall,
						region: requestedRegion
					)
				} else {
					self.isInstalled = false
					self.setRegionInstalled(requestedRegion, false)
					self.hasPartialDownload = false
					self.installedVersion = nil
					self.isGameUpdateAvailable = false
					self.lifecycle.setStatus(.uninstalled)
				}
			}
		}
	}

	@discardableResult
	package func retryUninstallFailure(id: UUID) -> Bool {
		guard let failure = lifecycle.failure, failure.id == id else { return false }
		guard failure.context.operation == .uninstall else { return false }
		guard failure.context.region == region.supportRegion else { return false }
		guard failure.actions.contains(.retry), canUninstallGame else { return false }
		guard lifecycle.consumeFailure(id: id) != nil else { return false }
		log.info(
			"Recovery selected; action=retry operation=uninstall region=\(region.rawValue)"
		)
		uninstallGame()
		return true
	}
}
