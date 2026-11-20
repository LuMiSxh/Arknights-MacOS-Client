// SPDX-License-Identifier: MPL-2.0

import AppKit
import Foundation

extension InstallationController {
	package func chooseInstallDirectory() {
		guard lifecycle.activity == .idle else { return }
		let panel = NSOpenPanel()
		panel.title = "Choose where to install Arknights"
		panel.prompt = "Choose"
		panel.canChooseDirectories = true
		panel.canChooseFiles = false
		panel.canCreateDirectories = true
		panel.allowsMultipleSelection = false
		panel.directoryURL = installDirectory.deletingLastPathComponent()
		if panel.runModal() == .OK, let selected = panel.url {
			assessInstallDirectory(selected)
		}
	}

	package func locateExistingInstallation() {
		guard lifecycle.activity == .idle else { return }
		let panel = NSOpenPanel()
		panel.title = "Choose the folder containing Arknights.exe"
		panel.prompt = "Use Folder"
		panel.canChooseDirectories = true
		panel.canChooseFiles = false
		panel.allowsMultipleSelection = false
		panel.directoryURL = installDirectory
		if panel.runModal() == .OK, let selected = panel.url {
			assessInstallDirectory(selected, expectsGameFiles: true)
			// A refused folder leaves the install directory unchanged.
			guard installDirectory == selected else { return }
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

	/// Only the launcher's default folder is wholly its own. Any other folder may hold the
	/// user's files, so uninstalling there removes only what the launcher installed.
	private var uninstallScope: UninstallScope {
		installDirectory.standardizedFileURL == paths.gameInstall(for: region).standardizedFileURL
			? .wholeFolder : .installedFilesOnly
	}

	package func uninstallGame() {
		guard canUninstallGame else { return }
		guard FileManager.default.fileExists(atPath: installDirectory.path) else {
			updateInstalledState()
			return
		}
		let directory = installDirectory
		let scope = uninstallScope
		let operationID = UUID()
		let requestedRegion = region
		guard let lease = lifecycle.begin(.maintaining(.uninstalling)) else { return }
		lifecycle.setStatus(.movingToTrash)
		log.info("Game uninstall requested")
		Task { [weak self, lifecycle = self.lifecycle, installer = self.installer] in
			defer { lifecycle.end(lease) }
			let outcome: UninstallOutcome
			do {
				outcome = try await installer.uninstall(from: directory, scope: scope)
			} catch {
				self?.presentInstallationFailure(
					error,
					id: operationID,
					operation: .uninstall,
					region: requestedRegion
				)
				return
			}
			guard let self else { return }
			if outcome == .installedFilesUnknown {
				updateInstalledState()
				presentInstallationFailure(
					InstallerError.installedFilesUnknown(directory),
					id: operationID,
					operation: .uninstall,
					region: requestedRegion
				)
				return
			}
			installPresence = .absent
			setRegionInstalled(requestedRegion, false)
			isGameUpdateAvailable = false
			lifecycle.setStatus(.uninstalled)
		}
	}

	@discardableResult
	package func retryUninstallFailure(id: UUID) -> Bool {
		guard let failure = lifecycle.state.presentation.failure, failure.id == id else {
			return false
		}
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
