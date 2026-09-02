// SPDX-License-Identifier: MPL-2.0

import AppKit
import CryptoKit
import Foundation
import UniformTypeIdentifiers

extension CustomizationController {
	func chooseCustomArtwork() {
		let panel = NSOpenPanel()
		panel.title = L10n.string(LauncherStrings.pickerLauncherArtwork)
		panel.prompt = L10n.string(LauncherStrings.pickerChoose)
		panel.allowedContentTypes = [.image]
		panel.canChooseDirectories = false
		panel.canChooseFiles = true
		panel.allowsMultipleSelection = false
		guard panel.runModal() == .OK, let selected = panel.url else { return }
		applyCustomArtwork(from: selected)
	}

	func applyCustomArtwork(from url: URL) {
		let operationID = beginArtworkMutation()
		let dataLoader = self.dataLoader
		Task { [weak self] in
			guard let self else { return }
			defer { self.finishArtworkMutation(operationID) }
			do {
				let data = try await dataLoader(url)
				guard self.artworkOperationID == operationID else { return }
				guard NSImage(data: data) != nil else {
					lifecycle.show(LauncherError.invalidCustomImage(url))
					return
				}
				await applyDirectCustomArtwork(data: data, operationID: operationID)
			} catch {
				guard self.artworkOperationID == operationID else { return }
				lifecycle.show(error)
			}
		}
	}

	/// Removes the saved artwork and delegates the replacement refresh to the caller that owns
	/// the active region's metadata request.
	func resetArtwork(
		isDeveloperMode: Bool = false,
		isDownloading: Bool,
		restartRefresh: @escaping @MainActor () -> Void
	) {
		guard !isDeveloperMode else { return }
		do {
			if FileManager.default.fileExists(atPath: paths.customArtwork.path) {
				try FileManager.default.removeItem(at: paths.customArtwork)
			}
		} catch {
			lifecycle.show(error)
			return
		}
		artworkOperationID = nil
		passiveArtworkOperationID = nil
		artworkMutationInFlight = false
		setHasPersistedCustomArtwork(false)
		customArtworkDidChange()
		guard !isDownloading else { return }
		lifecycle.refresh = .idle
		restartRefresh()
	}

	func applyDirectCustomArtwork(data: Data) async {
		let operationID = beginArtworkMutation()
		await applyDirectCustomArtwork(data: data, operationID: operationID)
	}

	private func applyDirectCustomArtwork(data: Data, operationID: UUID) async {
		let destination = paths.customArtwork
		let stagedURL = destination.appendingPathExtension("stage.\(operationID.uuidString)")
		do {
			let cacheKey = try await CustomizationImageIO.prepareArtwork(
				data,
				source: destination
			)
			guard artworkOperationID == operationID else { return }
			guard let image = NSImage(data: data) else {
				throw LauncherError.invalidCustomImage(destination)
			}
			try await dataStager(data, stagedURL)
			guard artworkOperationID == operationID else {
				discardStagedArtwork(at: stagedURL)
				return
			}
			try commitStagedArtwork(from: stagedURL, to: destination)
			setHasPersistedCustomArtwork(true)
			setHeroArtwork(image, themeCacheKey: cacheKey)
		} catch {
			discardStagedArtwork(at: stagedURL)
			guard artworkOperationID == operationID else { return }
			lifecycle.show(error)
		}
		finishArtworkMutation(operationID)
	}

	func loadCustomArtwork() async -> Bool {
		guard let (operationID, generation) = beginPassiveArtworkLoad() else { return false }
		let artworkURL = paths.customArtwork
		do {
			let data = try await dataLoader(artworkURL)
			guard isCurrentPassiveArtworkLoad(operationID, generation: generation) else {
				return false
			}
			let cacheKey = try await CustomizationImageIO.prepareArtwork(data, source: artworkURL)
			guard isCurrentPassiveArtworkLoad(operationID, generation: generation) else {
				return false
			}
			guard let image = NSImage(data: data) else {
				await log.error("Custom launcher artwork is not a valid image")
				return false
			}
			setHasPersistedCustomArtwork(true)
			setHeroArtwork(image, themeCacheKey: cacheKey)
			return true
		} catch {
			guard isCurrentPassiveArtworkLoad(operationID, generation: generation) else {
				return false
			}
			setHasPersistedCustomArtwork(false)
			if (error as? CocoaError)?.code == .fileReadNoSuchFile { return false }
			await log.error("Failed to load custom launcher artwork: \(error.localizedDescription)")
			return false
		}
	}

	/// Restores local artwork before the first SwiftUI frame, keeping cached Dynamic Theme colors
	/// available while the active region refreshes in the background.
	func restoreInitialArtwork(for region: GameRegion) async {
		let hasCustomArtwork = await loadCustomArtwork()
		if !hasCustomArtwork, !hasPersistedCustomArtwork, !artworkMutationInFlight,
			let (operationID, generation) = beginPassiveArtworkLoad()
		{
			await restoreInitialOfficialArtwork(
				for: region,
				operationID: operationID,
				generation: generation
			)
		}
		await restoreOfficialLogo(for: region).value
	}

	/// Clears any previous region's wordmark before a refresh can load the selected region's asset.
	@discardableResult
	func restoreOfficialLogo(for region: GameRegion) -> Task<Void, Never> {
		let operationID = UUID()
		officialLogoOperationID = operationID
		officialLogo = nil
		guard region != .china else { return Task {} }
		let artworkCache = self.artworkCache
		return Task { [weak self, log] in
			do {
				let data = try await Task.detached(priority: .utility) {
					try artworkCache.cachedOfficialLogoData(for: region)
				}.value
				guard
					let self,
					self.officialLogoOperationID == operationID,
					self.region() == region
				else { return }
				self.officialLogo = data.flatMap { NSImage(data: $0) }
			} catch {
				guard self?.officialLogoOperationID == operationID else { return }
				await log.error(
					"Failed to load cached logo for \(region.displayName): \(error.localizedDescription)"
				)
			}
		}
	}

	private func restoreInitialOfficialArtwork(
		for region: GameRegion,
		operationID: UUID,
		generation: UInt64
	) async {
		do {
			let cached = try await Task.detached(priority: .utility) { [artworkCache] in
				try artworkCache.cachedActiveImageData(for: region)
			}.value
			guard isCurrentPassiveArtworkLoad(operationID, generation: generation),
				self.region() == region,
				!hasPersistedCustomArtwork,
				let (cacheKey, data) = cached,
				let image = NSImage(data: data)
			else { return }
			setHeroArtwork(
				image,
				themeCacheKey: Self.officialThemeCacheKey(for: region, artworkCacheKey: cacheKey)
			)
		} catch {
			await log.error(
				"Failed to load cached artwork for \(region.displayName): \(error.localizedDescription)"
			)
		}
	}

	nonisolated static func customThemeCacheKey(for data: Data) -> String {
		// Kept synchronous for deterministic cache-key tests; production hashes in
		// `CustomizationImageIO.prepareArtwork` off the main actor.
		let digest = SHA256.hash(data: data)
		return "custom.\(digest.map { String(format: "%02x", $0) }.joined())"
	}

	private func beginArtworkMutation() -> UUID {
		let operationID = UUID()
		artworkOperationID = operationID
		passiveArtworkOperationID = nil
		artworkMutationInFlight = true
		customArtworkDidChange()
		return operationID
	}

	private func finishArtworkMutation(_ operationID: UUID) {
		guard artworkOperationID == operationID else { return }
		artworkMutationInFlight = false
	}

	private func beginPassiveArtworkLoad() -> (UUID, UInt64)? {
		guard !artworkMutationInFlight else { return nil }
		let operationID = UUID()
		passiveArtworkOperationID = operationID
		return (operationID, customArtworkGeneration)
	}

	private func isCurrentPassiveArtworkLoad(_ operationID: UUID, generation: UInt64) -> Bool {
		passiveArtworkOperationID == operationID
			&& customArtworkGeneration == generation
			&& !artworkMutationInFlight
	}

	private func commitStagedArtwork(from stagedURL: URL, to destination: URL) throws {
		let fileManager = FileManager.default
		if fileManager.fileExists(atPath: destination.path) {
			_ = try fileManager.replaceItemAt(destination, withItemAt: stagedURL)
		} else {
			try fileManager.moveItem(at: stagedURL, to: destination)
		}
	}

	private func discardStagedArtwork(at url: URL) {
		guard FileManager.default.fileExists(atPath: url.path) else { return }
		do {
			try FileManager.default.removeItem(at: url)
		} catch {
			Task { [log] in
				await log.error(
					"Failed to remove staged custom artwork at \(url.path): \(error.localizedDescription)"
				)
			}
		}
	}
}
