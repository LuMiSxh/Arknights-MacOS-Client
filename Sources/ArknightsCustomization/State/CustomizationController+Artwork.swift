// SPDX-License-Identifier: MPL-2.0

import AppKit
import ArknightsCore
import CryptoKit
import Foundation
import UniformTypeIdentifiers

extension CustomizationController {
	package func chooseCustomArtwork() {
		let panel = NSOpenPanel()
		panel.title = "Choose launcher artwork"
		panel.prompt = "Choose"
		panel.allowedContentTypes = [.image]
		panel.canChooseDirectories = false
		panel.canChooseFiles = true
		panel.allowsMultipleSelection = false
		guard panel.runModal() == .OK, let selected = panel.url else { return }
		applyCustomArtwork(from: selected)
	}

	package func applyCustomArtwork(from url: URL) {
		let operationID = beginArtworkMutation()
		let dataLoader = self.dataLoader
		Task { [weak self] in
			guard let self else { return }
			defer { self.finishArtworkMutation(operationID) }
			do {
				let data = try await dataLoader(url)
				guard self.artworkOperationID == operationID else { return }
				guard NSImage(data: data) != nil else {
					lifecycle.show(CustomizationError.invalidCustomImage(url))
					return
				}
				await applyDirectCustomArtwork(data: data, operationID: operationID)
			} catch {
				guard self.artworkOperationID == operationID else { return }
				lifecycle.show(error)
			}
		}
	}

	// Removes the saved artwork and delegates the replacement refresh to the caller that owns
	// the active region's metadata request.
	package func resetArtwork(
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
		passiveArtworkLoad.invalidate()
		artworkMutationInFlight = false
		setHasPersistedCustomArtwork(false)
		customArtworkDidChange()
		setHeroArtwork(nil, themeCacheKey: nil)
		guard !isDownloading else { return }
		lifecycle.state.refresh = .idle
		restartRefresh()
	}

	package func applyDirectCustomArtwork(data: Data) async {
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
			let decoded = await CustomizationImageIO.decodeImage(data)
			guard artworkOperationID == operationID else { return }
			guard let decoded else {
				throw CustomizationError.invalidCustomImage(destination)
			}
			let image = NSImage(cgImage: decoded, size: .zero)
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

	package func loadCustomArtwork() async -> Bool {
		guard let token = beginPassiveArtworkLoad() else { return false }
		let artworkURL = paths.customArtwork
		do {
			let data = try await dataLoader(artworkURL)
			guard ownsPassiveArtworkLoad(token) else { return false }
			let cacheKey = try await CustomizationImageIO.prepareArtwork(data, source: artworkURL)
			guard ownsPassiveArtworkLoad(token) else { return false }
			let decoded = await CustomizationImageIO.decodeImage(data)
			guard ownsPassiveArtworkLoad(token) else { return false }
			guard let decoded else {
				log.error("Custom launcher artwork is not a valid image")
				return false
			}
			let image = NSImage(cgImage: decoded, size: .zero)
			setHasPersistedCustomArtwork(true)
			setHeroArtwork(image, themeCacheKey: cacheKey)
			return true
		} catch {
			guard ownsPassiveArtworkLoad(token) else { return false }
			setHasPersistedCustomArtwork(false)
			if (error as? CocoaError)?.code == .fileReadNoSuchFile { return false }
			log.error(
				"Failed to load custom launcher artwork: \(launcherDiagnosticDescription(for: error))"
			)
			return false
		}
	}

	// Restores local artwork before the first SwiftUI frame, keeping cached Dynamic Theme colors
	// available while the active region refreshes in the background.
	package func restoreInitialArtwork(for region: GameRegion) async {
		let hasCustomArtwork = await loadCustomArtwork()
		if !hasCustomArtwork, !hasPersistedCustomArtwork, !artworkMutationInFlight,
			let token = beginPassiveArtworkLoad()
		{
			await restoreInitialOfficialArtwork(for: region, token: token)
		}
		await restoreOfficialLogo(for: region).value
	}

	// Clears any previous region's wordmark before a refresh can load the selected region's asset.
	@discardableResult
	package func restoreOfficialLogo(for region: GameRegion) -> Task<Void, Never> {
		officialLogoLoad.invalidate()
		officialLogo = nil
		let artworkCache = self.artworkCache
		return officialLogoLoad.replace { [weak self, log] token in
			do {
				let logo = try await Self.cachedOfficialLogo(in: artworkCache, for: region)
				guard
					let self,
					self.officialLogoLoad.owns(token),
					self.region() == region
				else { return }
				self.officialLogo = logo.map { NSImage(cgImage: $0, size: .zero) }
			} catch {
				guard self?.officialLogoLoad.owns(token) == true else { return }
				log.error(
					"Failed to load cached logo for \(region.displayName): \(error.localizedDescription)"
				)
			}
		}
	}

	private func restoreInitialOfficialArtwork(
		for region: GameRegion,
		token: TaskSlot.Token
	) async {
		do {
			let cached = try await Self.cachedActiveArtwork(in: artworkCache, for: region)
			guard ownsPassiveArtworkLoad(token),
				self.region() == region,
				!hasPersistedCustomArtwork,
				let cached
			else { return }
			setHeroArtwork(
				NSImage(cgImage: cached.image, size: .zero),
				themeCacheKey: Self.officialThemeCacheKey(
					for: region, artworkCacheKey: cached.cacheKey)
			)
		} catch {
			log.error(
				"Failed to load cached artwork for \(region.displayName): \(error.localizedDescription)"
			)
		}
	}

	@concurrent
	private static func cachedOfficialLogo(
		in artworkCache: ArtworkCache,
		for region: GameRegion
	) async throws -> CGImage? {
		guard let data = try artworkCache.cachedOfficialLogoData(for: region) else { return nil }
		return await CustomizationImageIO.decodeImage(data)
	}

	@concurrent
	private static func cachedActiveArtwork(
		in artworkCache: ArtworkCache,
		for region: GameRegion
	) async throws -> (cacheKey: String, image: CGImage)? {
		guard let (cacheKey, data) = try artworkCache.cachedActiveImageData(for: region),
			let image = await CustomizationImageIO.decodeImage(data)
		else { return nil }
		return (cacheKey, image)
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
		passiveArtworkLoad.invalidate()
		artworkMutationInFlight = true
		customArtworkDidChange()
		return operationID
	}

	private func finishArtworkMutation(_ operationID: UUID) {
		guard artworkOperationID == operationID else { return }
		artworkMutationInFlight = false
	}

	private func beginPassiveArtworkLoad() -> TaskSlot.Token? {
		guard !artworkMutationInFlight else { return nil }
		return passiveArtworkLoad.begin()
	}

	private func ownsPassiveArtworkLoad(_ token: TaskSlot.Token) -> Bool {
		passiveArtworkLoad.owns(token) && !artworkMutationInFlight
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
		log.attempt("Failed to remove staged custom artwork at \(url.path)") {
			try FileManager.default.removeItem(at: url)
		}
	}
}
