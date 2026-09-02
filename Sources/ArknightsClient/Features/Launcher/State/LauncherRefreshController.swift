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
	/// Metadata results are accepted only while this token owns the observable refresh state.
	/// The token is updated synchronously, before a newly-created task can suspend or run.
	@ObservationIgnored private var metadataRequestID: UUID?
	@ObservationIgnored private var brandingAssetTask: Task<Void, Never>?
	/// Asset results are accepted only for the currently active metadata refresh generation.
	/// Starting or cancelling a refresh invalidates the token before any older task can finish.
	@ObservationIgnored private var brandingRequestID: UUID?

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
		brandingAssetTask?.cancel()
	}

	@discardableResult
	func startRefresh(forceGameUpdateCheck: Bool = false) -> Task<Void, Never> {
		refreshTask?.cancel()
		brandingAssetTask?.cancel()
		brandingAssetTask = nil
		let refreshID = UUID()
		metadataRequestID = refreshID
		brandingRequestID = refreshID
		lifecycle.refresh = .checking(requestID: refreshID)
		let task = Task { [weak self] in
			guard let self else { return }
			await refresh(forceGameUpdateCheck: forceGameUpdateCheck, refreshID: refreshID)
		}
		refreshTask = task
		return task
	}

	func cancelRefresh() {
		refreshTask?.cancel()
		refreshTask = nil
		metadataRequestID = nil
		brandingAssetTask?.cancel()
		brandingAssetTask = nil
		brandingRequestID = nil
		lifecycle.refresh = .idle
	}

	func waitForCurrentRefresh() async {
		await refreshTask?.value
	}

	/// Stops metadata work because installation has exclusive ownership of the network and
	/// lifecycle state. The current region's already-started branding task remains valid and
	/// may finish applying its assets before the next normal refresh replaces it.
	func cancelForInstallationStart() {
		refreshTask?.cancel()
		refreshTask = nil
		metadataRequestID = nil
		lifecycle.refresh = .idle
	}

	func checkGameUpdates() {
		guard lifecycle.canBeginExclusiveActivity, !installation.isDownloading else { return }
		lifecycle.refresh = .idle
		startRefresh(forceGameUpdateCheck: true)
	}

	@discardableResult
	func retryConfigurationFailure(id: UUID) -> Bool {
		guard let failure = lifecycle.failure, failure.id == id else { return false }
		guard failure.actions.contains(.retry), lifecycle.canBeginExclusiveActivity else {
			return false
		}
		guard failure.context.operation == .configurationRefresh else { return false }
		guard failure.context.region == installation.region.supportRegion else { return false }
		guard lifecycle.consumeFailure(id: id) != nil else { return false }
		Task { [log] in
			await log.info(
				"Recovery selected; action=retry operation=configuration-refresh region=\(installation.region.rawValue)"
			)
		}
		lifecycle.refresh = .idle
		startRefresh(forceGameUpdateCheck: true)
		return true
	}

	@discardableResult
	func selectRegion(_ newRegion: GameRegion) -> Bool {
		guard installation.selectRegion(newRegion) else { return false }
		lifecycle.refresh = .checking(requestID: nil)
		refreshTask?.cancel()
		branding = nil
		customization.restoreOfficialLogo(for: newRegion)
		communication.resetPresentedNotice()
		settings.regionDidChange()
		lifecycle.setStatus(.checking)
		Task { [log] in await log.info("Region switched to \(newRegion.displayName)") }
		startRefresh()
		return true
	}

	private func refresh(forceGameUpdateCheck: Bool, refreshID: UUID) async {
		guard isCurrentRefresh(refreshID) else { return }
		await log.info("Refreshing game and branding state")
		guard isCurrentRefresh(refreshID) else { return }
		let region = installation.region
		await installation.updateInstalledState().value
		guard isCurrentRefresh(refreshID) else { return }
		if lifecycle.activity == .idle { lifecycle.setStatus(.checking) }
		_ = await customization.loadCustomArtwork()
		guard isCurrentRefresh(refreshID) else { return }
		let customArtworkGeneration = customization.customArtworkGeneration
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
				guard isCurrentRefresh(refreshID) else { return }
			} catch is CancellationError {
				return
			} catch {
				guard isCurrentRefresh(refreshID) else { return }
				if !installation.isInstalled || forceGameUpdateCheck {
					metadataRequestID = nil
					lifecycle.refresh = .idle
					presentConfigurationFailure(
						error,
						id: refreshID,
						region: region
					)
					return
				}
				await log.error(
					"Game configuration failed: \(launcherDiagnosticDescription(for: error))"
				)
				guard isCurrentRefresh(refreshID) else { return }
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
			guard isCurrentRefresh(refreshID) else { return }
			let assetTask = Task { [weak self] in
				guard let self else { return }
				await loadBrandingAssets(
					currentBranding,
					region: region,
					customArtworkGeneration: customArtworkGeneration,
					refreshID: refreshID
				)
			}
			brandingAssetTask = assetTask
		}

		guard isCurrentRefresh(refreshID) else { return }
		metadataRequestID = nil
		lifecycle.refresh = .idle
		if lifecycle.activity == .idle {
			lifecycle.setStatus(
				installation.isGameUpdateAvailable
					? .updateAvailable
					: (installation.isInstalled
						? .ready : (installation.hasPartialDownload ? .paused : .install))
			)
		}
		let completedState = lifecycle.activityMessage
		await log.info("Refresh completed; state=\(completedState)")
		guard isCurrentRefresh(refreshID) else { return }
	}

	private func presentConfigurationFailure(
		_ error: any Error,
		id: UUID,
		region: GameRegion
	) {
		let message = launcherUserMessage(for: error)
		lifecycle.presentFailure(
			LauncherFailurePresentation(
				id: id,
				message: message,
				code: .virga,
				context: SupportContext(
					operation: .configurationRefresh,
					region: region.supportRegion
				),
				actions: [.retry, .openTroubleshooting, .reportProblem],
				blocksGameLaunch: !installation.isInstalled
			),
			diagnostic: launcherDiagnosticDescription(for: error)
		)
	}

	func isCurrentRefresh(_ refreshID: UUID) -> Bool {
		metadataRequestID == refreshID && lifecycle.refresh.requestID == refreshID
			&& !Task.isCancelled
			&& !installation.isDownloading
	}

	private func loadBrandingAssets(
		_ branding: LauncherBranding,
		region: GameRegion,
		customArtworkGeneration: UInt64,
		refreshID: UUID
	) async {
		guard isCurrentBrandingAssetLoad(refreshID, region: region),
			!customization.hasPersistedCustomArtwork
		else { return }
		let customArtworkWasPersisted = customization.hasPersistedCustomArtwork
		let artworkCache = customization.artworkCache
		let logoTask = Task<Data?, Never> { [artworkCache, log] in
			do {
				return try await artworkCache.officialLogoData(for: region)
			} catch {
				await log.error(
					"Official \(region.displayName) logo load failed: \(error.localizedDescription)"
				)
				return nil
			}
		}
		let artworkTask = Task { [artworkCache, log] in
			guard !customArtworkWasPersisted else { return nil as Data? }
			do {
				return try await artworkCache.imageData(for: branding, region: region)
			} catch {
				await log.error(
					"Artwork for \(region.displayName) failed: \(error.localizedDescription)"
				)
				return nil
			}
		}
		let logoData = await withTaskCancellationHandler {
			await logoTask.value
		} onCancel: {
			logoTask.cancel()
		}
		guard isCurrentBrandingAssetLoad(refreshID, region: region) else {
			artworkTask.cancel()
			return
		}
		let artworkData = await withTaskCancellationHandler {
			await artworkTask.value
		} onCancel: {
			artworkTask.cancel()
		}
		guard
			isCurrentBrandingAssetLoad(refreshID, region: region)
		else { return }
		if let logoData, let logo = NSImage(data: logoData) {
			customization.officialLogo = logo
		}
		guard
			customization.customArtworkGeneration == customArtworkGeneration,
			!customization.hasPersistedCustomArtwork
		else { return }
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

	private func isCurrentBrandingAssetLoad(_ refreshID: UUID, region: GameRegion) -> Bool {
		brandingRequestID == refreshID && installation.region == region && !Task.isCancelled
	}
}
