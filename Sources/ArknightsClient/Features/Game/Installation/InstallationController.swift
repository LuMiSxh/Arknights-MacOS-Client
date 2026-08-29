// SPDX-License-Identifier: MPL-2.0

import Foundation
import Observation

/// Owns the selected regional installation, its readiness, and installer task lifecycle.
@MainActor
@Observable
final class InstallationController {
	var region: GameRegion
	var installDirectory: URL
	var progress: DownloadProgress?
	@ObservationIgnored var progressSequence: UInt64 = 0

	var configuration: GameConfiguration? {
		get { lifecycle.readiness.configuration }
		set { lifecycle.readiness.configuration = newValue }
	}
	var isInstalled: Bool {
		get { lifecycle.readiness.isInstalled }
		set { lifecycle.readiness.isInstalled = newValue }
	}
	var hasPartialDownload: Bool {
		get { lifecycle.readiness.hasPartialDownload }
		set { lifecycle.readiness.hasPartialDownload = newValue }
	}
	var installedVersion: String? {
		get { lifecycle.readiness.installedVersion }
		set { lifecycle.readiness.installedVersion = newValue }
	}
	var isGameUpdateAvailable: Bool {
		get { lifecycle.readiness.isGameUpdateAvailable }
		set { lifecycle.readiness.isGameUpdateAvailable = newValue }
	}

	var isDownloading: Bool { lifecycle.activity.isInstalling }
	var canInstall: Bool {
		lifecycle.activity == .idle && configuration != nil
	}
	var canModifyGameFiles: Bool { lifecycle.activity == .idle }

	let lifecycle: LauncherLifecycleStore
	let installer: any GameInstalling
	let paths: AppPaths
	let preferences: LauncherPreferencesStore
	let log: LauncherLog
	@ObservationIgnored var onLaunchRequested: (() -> Void)?
	@ObservationIgnored var onMetadataRefreshCancellationRequested: (() -> Void)?
	@ObservationIgnored var installationTask: Task<Void, Never>?
	var installationGate = ExclusiveOperationGate()

	init(
		lifecycle: LauncherLifecycleStore,
		installer: any GameInstalling,
		paths: AppPaths,
		preferences: LauncherPreferencesStore,
		log: LauncherLog,
		region: GameRegion? = nil
	) {
		self.lifecycle = lifecycle
		self.installer = installer
		self.paths = paths
		self.preferences = preferences
		self.log = log
		let selectedRegion = region ?? preferences.selectedRegion()
		self.region = selectedRegion
		installDirectory = preferences.installDirectory(
			for: selectedRegion,
			default: paths.gameInstall(for: selectedRegion)
		)
	}

	deinit {
		installationTask?.cancel()
	}

	func selectRegion(_ newRegion: GameRegion) -> Bool {
		guard newRegion != region, lifecycle.activity == .idle else { return false }
		lifecycle.clearFailure()
		region = newRegion
		preferences.setSelectedRegion(newRegion)
		configuration = nil
		isInstalled = false
		hasPartialDownload = false
		installedVersion = nil
		isGameUpdateAvailable = false
		progress = nil
		progressSequence = 0
		installDirectory = preferences.installDirectory(
			for: newRegion,
			default: paths.gameInstall(for: newRegion)
		)
		return true
	}

	func updateGameAvailability() {
		guard isInstalled, let latest = configuration?.gameLatestVersion else {
			isGameUpdateAvailable = false
			return
		}
		isGameUpdateAvailable = installedVersion.map { $0 != latest } ?? true
	}

	func updateInstalledState() {
		let hasExecutable = FileManager.default.fileExists(
			atPath: installDirectory.appending(path: "Arknights.exe").path
		)
		let installedState = loadInstalledState()
		isInstalled = hasExecutable && installedState != nil
		hasPartialDownload =
			!isInstalled && Self.containsPartialDownload(in: installDirectory)
		installedVersion = installedState?.version
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

	func waitForCurrentInstallation() async {
		await installationTask?.value
	}

	var installedRegions: [GameRegion] {
		GameRegion.allCases.filter(isRegionInstalled)
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
}
