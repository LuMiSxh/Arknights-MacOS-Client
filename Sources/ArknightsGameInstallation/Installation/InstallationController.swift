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
	/// A folder the user picked that the launcher refuses or asks about before using.
	package private(set) var pendingInstallDirectory: PendingInstallDirectory?
	package var progress: DownloadProgress?
	package private(set) var installedRegions: [GameRegion] = [] {
		didSet {
			if installedRegions != oldValue { onInstalledRegionsChanged?() }
		}
	}
	@ObservationIgnored package var onInstalledRegionsChanged: (() -> Void)?
	@ObservationIgnored var progressSequence: UInt64 = 0

	package var configuration: GameConfiguration? {
		get { lifecycle.state.readiness.configuration }
		set { lifecycle.state.readiness.configuration = newValue }
	}
	package var installPresence: InstallPresence {
		get { lifecycle.state.readiness.installPresence }
		set { lifecycle.state.readiness.installPresence = newValue }
	}
	package var isInstalled: Bool { installPresence.isInstalled }
	package var hasPartialDownload: Bool { installPresence == .partialDownload }
	package var installedVersion: String? { installPresence.installedVersion }
	package var isGameUpdateAvailable: Bool {
		get { lifecycle.state.readiness.isGameUpdateAvailable }
		set { lifecycle.state.readiness.isGameUpdateAvailable = newValue }
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
	@ObservationIgnored private let stateRefreshSlot = TaskSlot()

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

	// `TaskSlot` does not cancel on deinit, so cancel the in-flight refresh here.
	isolated deinit {
		installationTask?.cancel()
		stateRefreshSlot.invalidate()
	}

	package func selectRegion(_ newRegion: GameRegion) -> Bool {
		guard newRegion != region, lifecycle.activity.allowsRegionSwitch else { return false }

		cancelInstalledStateRefresh()
		pendingInstallDirectory = nil
		lifecycle.clearFailure()
		region = newRegion
		preferences.setSelectedRegion(newRegion)
		configuration = nil
		installPresence = .absent
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

	/// The install location of every server, including the default for unset servers.
	func configuredInstallDirectories() -> [GameRegion: URL] {
		Dictionary(
			uniqueKeysWithValues: GameRegion.allCases.map {
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
	}

	@discardableResult
	package func updateInstalledState() -> Task<Void, Never> {
		let request = InstallationStateRequest(
			selectedRegion: region,
			selectedDirectory: installDirectory,
			regionDirectories: configuredInstallDirectories()
		)
		let stateLoader = self.stateLoader
		return stateRefreshSlot.replace { [weak self, log] token in
			do {
				let snapshot = try await stateLoader(request)
				guard let self, self.ownsStateRefresh(token, request: request) else {
					return
				}
				self.installPresence = snapshot.installPresence
				self.installedRegions = snapshot.installedRegions.filter {
					self.currentSelectableRegions.contains($0)
				}
				if let diagnostic = snapshot.diagnostic {
					log.info(.install, "state-diagnostic", ["detail": diagnostic])
				}
			} catch is CancellationError {
				return
			} catch {
				guard let self, self.ownsStateRefresh(token, request: request) else {
					return
				}
				log.warning(
					.install, "state-inspection-failed",
					["server": request.selectedRegion.rawValue], error: error)
			}
		}
	}

	package func cancelInstalledStateRefresh() {
		stateRefreshSlot.invalidate()
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

	/// Uses a refused or unconfirmed folder only after the user confirms it.
	package func confirmPendingInstallDirectory() {
		guard let pending = pendingInstallDirectory, !pending.issue.isRefusal else { return }
		pendingInstallDirectory = nil
		guard lifecycle.activity == .idle else { return }
		applyInstallDirectory(pending.url)
	}

	package func dismissPendingInstallDirectory() {
		pendingInstallDirectory = nil
	}

	/// `expectsGameFiles` is set when the user locates an existing installation: a folder
	/// with files is then the point, so only refusals stop it.
	func assessInstallDirectory(_ selected: URL, expectsGameFiles: Bool = false) {
		do {
			let contents = try InstallDirectoryPolicy.inspect(selected)
			let issue = InstallDirectoryPolicy.assess(
				candidate: selected,
				region: region,
				configuredDirectories: configuredInstallDirectories(),
				launcherDataRoot: paths.applicationSupportRoot,
				homeDirectory: FileManager.default.homeDirectoryForCurrentUser,
				contents: contents
			)
			if let issue, issue.isRefusal || !expectsGameFiles {
				pendingInstallDirectory = PendingInstallDirectory(url: selected, issue: issue)
			} else {
				applyInstallDirectory(selected)
			}
		} catch {
			log.warning(
				.install, "folder-read-failed",
				["path": selected], error: error)
		}
	}

	private func applyInstallDirectory(_ url: URL) {
		installDirectory = url
		preferences.setInstallDirectory(url, for: region)
		updateInstalledState()
	}

	private func ownsStateRefresh(
		_ token: TaskSlot.Token,
		request: InstallationStateRequest
	) -> Bool {
		stateRefreshSlot.owns(token) && !Task.isCancelled
			&& region == request.selectedRegion
			&& installDirectory == request.selectedDirectory
	}

	private var currentSelectableRegions: Set<GameRegion> {
		Set(
			GameRegion.allCases
		)
	}
}
