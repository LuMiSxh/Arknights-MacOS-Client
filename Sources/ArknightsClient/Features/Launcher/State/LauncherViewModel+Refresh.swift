// SPDX-License-Identifier: MPL-2.0

import AppKit
import Foundation

extension LauncherViewModel {
	var canSwitchRegion: Bool {
		state.activity == .idle
	}

	func selectRegion(_ newRegion: GameRegion) {
		guard newRegion != region, canSwitchRegion else { return }
		region = newRegion
		preferences.setSelectedRegion(newRegion)
		state.refresh = .checking(requestID: nil)
		refreshTask?.cancel()
		configuration = nil
		branding = nil
		// Keep the previous branding visible until the replacement is ready. Clearing it here
		// makes Dynamic Theme fall back to the default accent between region requests.
		isInstalled = false
		hasPartialDownload = false
		installedVersion = nil
		isGameUpdateAvailable = false
		progress = nil
		presentedNoticeContent = nil
		installDirectory = preferences.installDirectory(
			for: newRegion,
			default: paths.gameInstall(for: newRegion)
		)
		setStatus(.checking)
		Task { [log] in await log.info("Region switched to \(newRegion.displayName)") }
		refreshTask = Task { [weak self] in await self?.refresh() }
	}

	func refresh(forceGameUpdateCheck: Bool = false) async {
		guard !isDownloading else { return }
		await log.info("Refreshing game and branding state")
		let refreshID = UUID()
		let region = region
		state.refresh = .checking(requestID: refreshID)
		updateInstalledState()
		if state.activity == .idle { setStatus(.checking) }
		let hasCustomArtwork = await loadCustomArtwork()
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

		if !isInstalled || automaticallyChecksGameUpdates || forceGameUpdateCheck {
			do {
				let fetchedConfiguration = try await api.gameConfiguration(region: region)
				guard isCurrentRefresh(refreshID) else { return }
				configuration = fetchedConfiguration
				updateGameAvailability()
				await log.info(
					"Game configuration loaded; latest=\(fetchedConfiguration.gameLatestVersion)"
				)
			} catch is CancellationError {
				return
			} catch {
				guard isCurrentRefresh(refreshID) else { return }
				if !isInstalled {
					state.refresh = .idle
					show(error, context: "Game configuration failed")
					return
				}
				await log.error(
					"Game configuration failed: \(launcherDiagnosticDescription(for: error))"
				)
			}
		}

		let fetchedBranding = await brandingTask.value
		guard isCurrentRefresh(refreshID) else { return }
		if let currentBranding = fetchedBranding {
			branding = currentBranding
			presentNoticeIfNeeded(currentBranding)
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
		state.refresh = .idle
		if state.activity == .idle {
			setStatus(
				isGameUpdateAvailable
					? .updateAvailable
					: (isInstalled ? .ready : (hasPartialDownload ? .paused : .install))
			)
		}
		await log.info("Refresh completed; state=\(activityMessage)")
	}

	private func loadBrandingAssets(
		_ branding: LauncherBranding,
		region: GameRegion,
		hasCustomArtwork: Bool,
		refreshID: UUID
	) async {
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
		let (logoData, artworkData) = await (logoTask.value, artworkTask.value)
		guard isCurrentRefresh(refreshID) else { return }
		if let logoData { officialLogo = NSImage(data: logoData) }
		if let artworkData,
			let image = NSImage(data: artworkData),
			let artworkCacheKey = artworkCache.cacheKey(for: branding)
		{
			setHeroArtwork(
				image,
				themeCacheKey: Self.officialThemeCacheKey(
					for: region,
					artworkCacheKey: artworkCacheKey
				)
			)
		}
	}
}
