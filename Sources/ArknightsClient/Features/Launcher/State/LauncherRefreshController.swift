// SPDX-License-Identifier: MPL-2.0

import AppKit
import Foundation
import Observation

/// Coordinates region selection and concurrent Yostar configuration and branding refreshes.
@MainActor
@Observable
final class LauncherRefreshController {
	var branding: LauncherBranding?
	var canSwitchRegion: Bool { lifecycle.activity == .idle }

	private let lifecycle: LauncherLifecycleStore
	private let installation: InstallationController
	private let customization: CustomizationController
	private let communication: LauncherCommunicationController
	private let settings: LauncherPreferencesController
	private let api: any LauncherAPIProviding
	private let log: LauncherLog
	@ObservationIgnored private var refreshTask: Task<Void, Never>?

	init(
		lifecycle: LauncherLifecycleStore,
		installation: InstallationController,
		customization: CustomizationController,
		communication: LauncherCommunicationController,
		settings: LauncherPreferencesController,
		api: any LauncherAPIProviding,
		log: LauncherLog
	) {
		self.lifecycle = lifecycle
		self.installation = installation
		self.customization = customization
		self.communication = communication
		self.settings = settings
		self.api = api
		self.log = log
	}

	deinit {
		refreshTask?.cancel()
	}

	@discardableResult
	func startRefresh(forceGameUpdateCheck: Bool = false) -> Task<Void, Never> {
		refreshTask?.cancel()
		let task = Task { [weak self] in
			guard let self else { return }
			await refresh(forceGameUpdateCheck: forceGameUpdateCheck)
		}
		refreshTask = task
		return task
	}

	func cancelRefresh() {
		refreshTask?.cancel()
		refreshTask = nil
	}

	func checkGameUpdates() {
		guard !installation.isDownloading else { return }
		lifecycle.refresh = .idle
		startRefresh(forceGameUpdateCheck: true)
	}

	@discardableResult
	func selectRegion(_ newRegion: GameRegion) -> Bool {
		guard installation.selectRegion(newRegion) else { return false }
		lifecycle.refresh = .checking(requestID: nil)
		refreshTask?.cancel()
		branding = nil
		communication.resetPresentedNotice()
		settings.regionDidChange()
		lifecycle.setStatus(.checking)
		Task { [log] in await log.info("Region switched to \(newRegion.displayName)") }
		startRefresh()
		return true
	}

	func refresh(forceGameUpdateCheck: Bool = false) async {
		guard !installation.isDownloading else { return }
		await log.info("Refreshing game and branding state")
		let refreshID = UUID()
		let region = installation.region
		lifecycle.refresh = .checking(requestID: refreshID)
		installation.updateInstalledState()
		if lifecycle.activity == .idle { lifecycle.setStatus(.checking) }
		let hasCustomArtwork = await customization.loadCustomArtwork()
		let brandingTask = Task<LauncherBranding?, Never> { [api, log] in
			do {
				return try await api.branding(region: region)
			} catch is CancellationError {
				return nil
			} catch {
				await log.error(
					"Branding for \(region.displayName) failed: \(launcherDiagnosticDescription(for: error))"
				)
				return nil
			}
		}
		defer { brandingTask.cancel() }

		if !installation.isInstalled || settings.automaticallyChecksGameUpdates
			|| forceGameUpdateCheck
		{
			do {
				let fetchedConfiguration = try await api.gameConfiguration(region: region)
				guard isCurrentRefresh(refreshID) else { return }
				installation.configuration = fetchedConfiguration
				installation.updateGameAvailability()
				await log.info(
					"Game configuration loaded; latest=\(fetchedConfiguration.gameLatestVersion)"
				)
			} catch is CancellationError {
				return
			} catch {
				guard isCurrentRefresh(refreshID) else { return }
				if !installation.isInstalled {
					lifecycle.refresh = .idle
					lifecycle.show(error, context: "Game configuration failed")
					return
				}
				await log.error(
					"Game configuration failed: \(launcherDiagnosticDescription(for: error))"
				)
			}
		}

		let fetchedBranding = await withTaskCancellationHandler {
			await brandingTask.value
		} onCancel: {
			brandingTask.cancel()
		}
		guard isCurrentRefresh(refreshID) else { return }
		if let currentBranding = fetchedBranding {
			branding = currentBranding
			communication.presentNoticeIfNeeded(currentBranding)
			await log.info(
				"Branding loaded; noticeEnabled=\(currentBranding.noticePopOpen == true)"
			)
			await loadBrandingAssets(
				currentBranding,
				region: region,
				hasCustomArtwork: hasCustomArtwork,
				refreshID: refreshID
			)
		}

		guard isCurrentRefresh(refreshID) else { return }
		lifecycle.refresh = .idle
		if lifecycle.activity == .idle {
			lifecycle.setStatus(
				installation.isGameUpdateAvailable
					? .updateAvailable
					: (installation.isInstalled
						? .ready : (installation.hasPartialDownload ? .paused : .install))
			)
		}
		await log.info("Refresh completed; state=\(lifecycle.activityMessage)")
	}

	func isCurrentRefresh(_ refreshID: UUID) -> Bool {
		lifecycle.refresh.requestID == refreshID && !Task.isCancelled
			&& !installation.isDownloading
	}

	private func loadBrandingAssets(
		_ branding: LauncherBranding,
		region: GameRegion,
		hasCustomArtwork: Bool,
		refreshID: UUID
	) async {
		let artworkCache = customization.artworkCache
		let logoTask = Task { [artworkCache, log] in
			guard branding.launcherBackgroundImage != nil else { return nil as Data? }
			do {
				return try await artworkCache.officialLogoData()
			} catch {
				await log.error("Official logo load failed: \(error.localizedDescription)")
				return nil
			}
		}
		let artworkTask = Task { [artworkCache, log] in
			guard !hasCustomArtwork else { return nil as Data? }
			do {
				return try await artworkCache.imageData(for: branding, region: region)
			} catch {
				await log.error(
					"Artwork for \(region.displayName) failed: \(error.localizedDescription)"
				)
				return nil
			}
		}
		let (logoData, artworkData) = await withTaskCancellationHandler {
			await (logoTask.value, artworkTask.value)
		} onCancel: {
			logoTask.cancel()
			artworkTask.cancel()
		}
		guard isCurrentRefresh(refreshID) else { return }
		if let logoData { customization.officialLogo = NSImage(data: logoData) }
		if let artworkData,
			let image = NSImage(data: artworkData),
			let artworkCacheKey = artworkCache.cacheKey(for: branding)
		{
			customization.setHeroArtwork(
				image,
				themeCacheKey: CustomizationController.officialThemeCacheKey(
					for: region,
					artworkCacheKey: artworkCacheKey
				)
			)
		}
	}
}
