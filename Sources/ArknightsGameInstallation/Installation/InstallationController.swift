// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation
import Observation

/// Owns the selected regional installation, its readiness, and installer task lifecycle.
@MainActor
@Observable
package final class InstallationController {
	package typealias StateLoader =
		@Sendable (InstallationStateRequest) async throws -> InstallationStateSnapshot

	package var region: GameRegion
	package var installDirectory: URL
	package var progress: DownloadProgress?
	package private(set) var completionFeedback: InstallationCompletionFeedback?
	package private(set) var installedRegions: [GameRegion] = []
	@ObservationIgnored var progressSequence: UInt64 = 0

	package var configuration: GameConfiguration? {
		get { lifecycle.readiness.configuration }
		set { lifecycle.readiness.configuration = newValue }
	}
	package var isInstalled: Bool {
		get { lifecycle.readiness.isInstalled }
		set { lifecycle.readiness.isInstalled = newValue }
	}
	package var hasPartialDownload: Bool {
		get { lifecycle.readiness.hasPartialDownload }
		set { lifecycle.readiness.hasPartialDownload = newValue }
	}
	package var installedVersion: String? {
		get { lifecycle.readiness.installedVersion }
		set { lifecycle.readiness.installedVersion = newValue }
	}
	package var isGameUpdateAvailable: Bool {
		get { lifecycle.readiness.isGameUpdateAvailable }
		set { lifecycle.readiness.isGameUpdateAvailable = newValue }
	}

	package var isDownloading: Bool { lifecycle.activity.isInstalling }
	package var canInstall: Bool {
		lifecycle.activity == .idle && configuration != nil
	}
	package var canModifyGameFiles: Bool { lifecycle.activity == .idle }
	package var canUninstallGame: Bool { canModifyGameFiles && (isInstalled || hasPartialDownload) }

	package let lifecycle: LauncherLifecycleStore
	let installer: any GameInstalling
	let paths: AppPaths
	let preferences: LauncherPreferencesStore
	let log: LauncherLog
	private let stateLoader: StateLoader
	@ObservationIgnored package var onLaunchRequested: (() -> Void)?
	@ObservationIgnored package var onMetadataRefreshCancellationRequested: (() -> Void)?
	@ObservationIgnored var installationTask: Task<Void, Never>?
	@ObservationIgnored var activityLease: ActivityLease?
	@ObservationIgnored private var stateRefreshTask: Task<Void, Never>?
	@ObservationIgnored private var stateRefreshID: UUID?

	package init(
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
				try await InstallationStateReader.loadOffCaller(request)
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

	package func selectRegion(_ newRegion: GameRegion) -> Bool {
		guard newRegion != region, lifecycle.activity == .idle else { return false }
		guard preferences.regionAccess().allows(newRegion) else { return false }
		cancelInstalledStateRefresh()
		completionFeedback = nil
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

	package func reloadInstallDirectory() {
		installDirectory = preferences.installDirectory(
			for: region,
			default: paths.gameInstall(for: region)
		)
	}

	package func updateGameAvailability() {
		guard isInstalled, let latest = configuration?.gameLatestVersion else {
			isGameUpdateAvailable = false
			return
		}
		isGameUpdateAvailable = installedVersion.map { $0 != latest } ?? true
	}

	@discardableResult
	package func updateInstalledState() -> Task<Void, Never> {
		cancelInstalledStateRefresh()
		let request = InstallationStateRequest(
			selectedRegion: region,
			selectedDirectory: installDirectory,
			regionDirectories: Dictionary(
				uniqueKeysWithValues: preferences.regionAccess().selectableRegions.map {
					candidate in
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
				self.installedRegions = snapshot.installedRegions.filter {
					self.currentSelectableRegions.contains($0)
				}
				self.finishStateRefresh(refreshID)
				if let diagnostic = snapshot.diagnostic {
					log.error(diagnostic)
				}
			} catch is CancellationError {
				self?.finishStateRefresh(refreshID)
			} catch {
				guard let self, self.ownsStateRefresh(refreshID, request: request) else {
					return
				}
				self.finishStateRefresh(refreshID)
				log.error(
					"Failed to inspect installation state for \(request.selectedRegion.displayName): \(error.localizedDescription)"
				)
			}
		}
		stateRefreshTask = task
		return task
	}

	package func cancelInstalledStateRefresh() {
		stateRefreshTask?.cancel()
		stateRefreshTask = nil
		stateRefreshID = nil
	}

	package func setRegionInstalled(_ candidate: GameRegion, _ installed: Bool) {
		if installed {
			guard currentSelectableRegions.contains(candidate) else {
				installedRegions.removeAll { $0 == candidate }
				return
			}
			if !installedRegions.contains(candidate) {
				installedRegions.append(candidate)
				installedRegions.sort { $0.rawValue < $1.rawValue }
			}
		} else {
			installedRegions.removeAll { $0 == candidate }
		}
	}

	package func isRegionInstalled(_ candidate: GameRegion) -> Bool {
		installedRegions.contains(candidate)
	}

	func waitForCurrentInstallation() async {
		await installationTask?.value
	}

	package func consumeCompletionFeedback(for region: GameRegion)
		-> InstallationCompletionFeedback?
	{
		guard let completionFeedback, completionFeedback.region == region else { return nil }
		self.completionFeedback = nil
		return completionFeedback
	}

	func clearCompletionFeedback() {
		completionFeedback = nil
	}

	func publishCompletionFeedback(for operationID: UUID, region: GameRegion) {
		guard self.region == region else { return }
		completionFeedback = InstallationCompletionFeedback(id: operationID, region: region)
	}

	private func ownsStateRefresh(
		_ id: UUID,
		request: InstallationStateRequest
	) -> Bool {
		stateRefreshID == id && !Task.isCancelled
			&& region == request.selectedRegion
			&& installDirectory == request.selectedDirectory
	}

	private var currentSelectableRegions: Set<GameRegion> {
		Set(
			preferences.regionAccess().selectableRegions
		)
	}

	private func finishStateRefresh(_ id: UUID) {
		guard stateRefreshID == id else { return }
		stateRefreshID = nil
		stateRefreshTask = nil
	}
}
