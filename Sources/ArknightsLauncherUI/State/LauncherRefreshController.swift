// SPDX-License-Identifier: MPL-2.0

import AppKit
import ArknightsCore
import ArknightsCustomization
import ArknightsGameInstallation
import Foundation
import Observation

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
	// Metadata results are accepted only while this slot owns the observable refresh state.
	@ObservationIgnored private let metadataSlot = TaskSlot()
	// Starting or cancelling a refresh invalidates the slot before any older asset task can finish.
	@ObservationIgnored private let brandingSlot = TaskSlot()

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
		brandingSlot.invalidate()
		let refreshID = UUID()
		lifecycle.state.refresh = .checking(requestID: refreshID)
		let task = metadataSlot.replace { [weak self] token in
			guard let self else { return }
			await refresh(
				forceGameUpdateCheck: forceGameUpdateCheck, refreshID: refreshID, token: token)
		}
		refreshTask = task
		return task
	}

	func cancelRefresh() {
		metadataSlot.invalidate()
		brandingSlot.invalidate()
		refreshTask = nil
		lifecycle.state.refresh = .idle
	}

	func waitForCurrentRefresh() async {
		await refreshTask?.value
	}

	// Stops metadata work because installation has exclusive ownership of the network and
	// lifecycle state. The current region's already-started branding task remains valid and
	// may finish applying its assets before the next normal refresh replaces it.
	func cancelForInstallationStart() {
		metadataSlot.invalidate()
		refreshTask = nil
		lifecycle.state.refresh = .idle
	}

	package func checkGameUpdates() {
		guard lifecycle.canBeginExclusiveActivity, !installation.isDownloading else { return }
		lifecycle.state.refresh = .idle
		startRefresh(forceGameUpdateCheck: true)
	}

	@discardableResult
	func retryConfigurationFailure(id: UUID) -> Bool {
		guard let failure = lifecycle.state.presentation.failure, failure.id == id else {
			return false
		}
		guard failure.actions.contains(.retry), lifecycle.canBeginExclusiveActivity else {
			return false
		}
		guard failure.context.operation == .configurationRefresh else { return false }
		guard failure.context.region == installation.region.supportRegion else { return false }
		guard lifecycle.consumeFailure(id: id) != nil else { return false }
		log.info(
			"Recovery selected; action=retry operation=configuration-refresh region=\(installation.region.rawValue)"
		)
		lifecycle.state.refresh = .idle
		startRefresh(forceGameUpdateCheck: true)
		return true
	}

	@discardableResult
	package func selectRegion(_ newRegion: GameRegion) -> Bool {
		guard installation.selectRegion(newRegion) else { return false }
		lifecycle.state.refresh = .checking(requestID: nil)
		branding = nil
		customization.restoreOfficialLogo(for: newRegion)
		communication.resetPresentedNotice()
		lifecycle.setStatus(.checking)
		log.info("Region switched to \(newRegion.displayName)")
		startRefresh()
		return true
	}

	private func refresh(
		forceGameUpdateCheck: Bool, refreshID: UUID, token: TaskSlot.Token
	) async {
		guard isCurrentRefresh(refreshID, token) else { return }
		log.info("Refreshing game and branding state")
		let region = installation.region
		await installation.updateInstalledState().value
		guard isCurrentRefresh(refreshID, token) else { return }
		if lifecycle.activity == .idle { lifecycle.setStatus(.checking) }
		_ = await customization.loadCustomArtwork()
		guard isCurrentRefresh(refreshID, token) else { return }
		let customArtworkGeneration = customization.customArtworkGeneration
		let brandingTask = Task<LauncherBranding?, Never> { [api, log] in
			do {
				return try await api.branding(region: region)
			} catch is CancellationError {
				return nil
			} catch {
				log.error(
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
				guard isCurrentRefresh(refreshID, token) else { return }
				installation.configuration = fetchedConfiguration
				installation.updateGameAvailability()
				log.info(
					"Game configuration loaded; latest=\(fetchedConfiguration.gameLatestVersion)"
				)
			} catch is CancellationError {
				return
			} catch {
				guard isCurrentRefresh(refreshID, token) else { return }
				if !installation.isInstalled || forceGameUpdateCheck {
					metadataSlot.invalidate()
					lifecycle.state.refresh = .idle
					presentConfigurationFailure(
						error,
						id: refreshID,
						region: region
					)
					return
				}
				log.error(
					"Game configuration failed: \(launcherDiagnosticDescription(for: error))"
				)
			}
		}

		let fetchedBranding = await withTaskCancellationHandler {
			await brandingTask.value
		} onCancel: {
			brandingTask.cancel()
		}
		guard isCurrentRefresh(refreshID, token) else { return }
		if let currentBranding = fetchedBranding {
			branding = currentBranding
			communication.presentNoticeIfNeeded(currentBranding)
			log.info(
				"Branding loaded; noticeEnabled=\(currentBranding.noticePopOpen == true)"
			)
			brandingSlot.replace { [weak self] brandingToken in
				guard let self else { return }
				await loadBrandingAssets(
					currentBranding,
					region: region,
					customArtworkGeneration: customArtworkGeneration,
					token: brandingToken
				)
			}
		}

		metadataSlot.invalidate()
		lifecycle.state.refresh = .idle
		if lifecycle.activity == .idle {
			lifecycle.setStatus(
				installation.isGameUpdateAvailable
					? .updateAvailable
					: (installation.isInstalled
						? .ready : (installation.hasPartialDownload ? .paused : .install))
			)
		}
		let completedState = lifecycle.state.presentation.status.message
		log.info("Refresh completed; state=\(completedState)")
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
				code: (error as? any SupportCodeProviding)?.supportCode
					?? (error is URLError ? .networkUnavailable : .serviceError),
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

	func isCurrentRefresh(_ refreshID: UUID, _ token: TaskSlot.Token) -> Bool {
		metadataSlot.owns(token) && lifecycle.state.refresh.requestID == refreshID
			&& !Task.isCancelled
			&& !installation.isDownloading
	}

	private func loadBrandingAssets(
		_ branding: LauncherBranding,
		region: GameRegion,
		customArtworkGeneration: UInt64,
		token: TaskSlot.Token
	) async {
		let customArtworkWasPersisted = customization.hasPersistedCustomArtwork
		guard isCurrentBrandingAssetLoad(token, region: region), !customArtworkWasPersisted
		else { return }
		let artworkCache = customization.artworkCache
		let logoTask = Task<Data?, Never> { [artworkCache, log] in
			do {
				return try await artworkCache.officialLogoData(for: region)
			} catch {
				log.error(
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
				log.error(
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
		guard isCurrentBrandingAssetLoad(token, region: region) else {
			artworkTask.cancel()
			return
		}
		let artworkData = await withTaskCancellationHandler {
			await artworkTask.value
		} onCancel: {
			artworkTask.cancel()
		}
		guard
			isCurrentBrandingAssetLoad(token, region: region)
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

	private func isCurrentBrandingAssetLoad(_ token: TaskSlot.Token, region: GameRegion) -> Bool {
		brandingSlot.owns(token) && installation.region == region && !Task.isCancelled
	}
}
