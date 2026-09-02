// SPDX-License-Identifier: MPL-2.0

import Foundation
import Observation

/// Owns the selected regional installation, its readiness, and installer task lifecycle.
@MainActor
@Observable
final class InstallationController {
	typealias StateLoader =
		@Sendable (InstallationStateRequest) async throws -> InstallationStateSnapshot

	var region: GameRegion
	var installDirectory: URL
	var progress: DownloadProgress?
	private(set) var installedRegions: [GameRegion] = []
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
	private let stateLoader: StateLoader
	@ObservationIgnored var onLaunchRequested: (() -> Void)?
	@ObservationIgnored var onMetadataRefreshCancellationRequested: (() -> Void)?
	@ObservationIgnored var installationTask: Task<Void, Never>?
	@ObservationIgnored private var stateRefreshTask: Task<Void, Never>?
	@ObservationIgnored private var stateRefreshID: UUID?
	var installationGate = ExclusiveOperationGate()

	init(
		lifecycle: LauncherLifecycleStore,
		installer: any GameInstalling,
		paths: AppPaths,
		preferences: LauncherPreferencesStore,
		log: LauncherLog,
		region: GameRegion? = nil,
		stateLoader: StateLoader? = nil
	) {
		self.lifecycle = lifecycle
		self.installer = installer
		self.paths = paths
		self.preferences = preferences
		self.log = log
		self.stateLoader =
			stateLoader ?? { request in
				let task = Task.detached(priority: .utility) {
					try InstallationStateReader.load(request)
				}
				return try await withTaskCancellationHandler {
					try await task.value
				} onCancel: {
					task.cancel()
				}
			}
		let selectedRegion = region ?? preferences.selectedRegion()
		self.region = selectedRegion
		installDirectory = preferences.installDirectory(
			for: selectedRegion,
			default: paths.gameInstall(for: selectedRegion)
		)
	}

	deinit {
		installationTask?.cancel()
		stateRefreshTask?.cancel()
	}

	func selectRegion(_ newRegion: GameRegion) -> Bool {
		guard newRegion != region, lifecycle.activity == .idle else { return false }
		guard newRegion != .china || preferences.canaryFeaturesEnabled() else { return false }
		cancelInstalledStateRefresh()
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

	@discardableResult
	func updateInstalledState() -> Task<Void, Never> {
		cancelInstalledStateRefresh()
		let request = InstallationStateRequest(
			selectedRegion: region,
			selectedDirectory: installDirectory,
			regionDirectories: Dictionary(
				uniqueKeysWithValues: GameRegion.selectableCases(
					canaryEnabled: preferences.canaryFeaturesEnabled()
				).map { candidate in
					(
						candidate,
						preferences.installDirectory(
							for: candidate,
							default: paths.gameInstall(for: candidate)
						)
					)
				}
			)
		)
		let refreshID = UUID()
		stateRefreshID = refreshID
		let stateLoader = self.stateLoader
		let task = Task { [weak self, log] in
			do {
				let snapshot = try await stateLoader(request)
				guard let self, self.ownsStateRefresh(refreshID, request: request) else {
					return
				}
				self.isInstalled = snapshot.isInstalled
				self.hasPartialDownload = snapshot.hasPartialDownload
				self.installedVersion = snapshot.installedVersion
				self.installedRegions = snapshot.installedRegions
				self.finishStateRefresh(refreshID)
				if let diagnostic = snapshot.diagnostic {
					await log.error(diagnostic)
				}
			} catch is CancellationError {
				self?.finishStateRefresh(refreshID)
			} catch {
				guard let self, self.ownsStateRefresh(refreshID, request: request) else {
					return
				}
				self.finishStateRefresh(refreshID)
				await log.error(
					"Failed to inspect installation state for \(request.selectedRegion.displayName): \(error.localizedDescription)"
				)
			}
		}
		stateRefreshTask = task
		return task
	}

	func cancelInstalledStateRefresh() {
		stateRefreshTask?.cancel()
		stateRefreshTask = nil
		stateRefreshID = nil
	}

	func setRegionInstalled(_ candidate: GameRegion, _ installed: Bool) {
		if installed {
			if !installedRegions.contains(candidate) {
				installedRegions.append(candidate)
				installedRegions.sort { $0.rawValue < $1.rawValue }
			}
		} else {
			installedRegions.removeAll { $0 == candidate }
		}
	}

	func isRegionInstalled(_ candidate: GameRegion) -> Bool {
		installedRegions.contains(candidate)
	}

	func waitForCurrentInstallation() async {
		await installationTask?.value
	}

	private func ownsStateRefresh(
		_ id: UUID,
		request: InstallationStateRequest
	) -> Bool {
		stateRefreshID == id && !Task.isCancelled
			&& region == request.selectedRegion
			&& installDirectory == request.selectedDirectory
	}

	private func finishStateRefresh(_ id: UUID) {
		guard stateRefreshID == id else { return }
		stateRefreshID = nil
		stateRefreshTask = nil
	}
}
