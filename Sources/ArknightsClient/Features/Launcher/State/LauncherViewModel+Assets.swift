// SPDX-License-Identifier: MPL-2.0

import AppKit
import CryptoKit
import Foundation
import UniformTypeIdentifiers

extension LauncherViewModel {
	func chooseCustomArtwork() {
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

	func applyCustomArtwork(from url: URL) {
		Task { [weak self] in
			guard let self else { return }
			do {
				let data = try await Task.detached(priority: .userInitiated) {
					try Data(contentsOf: url, options: .mappedIfSafe)
				}.value
				guard NSImage(data: data) != nil else {
					show(LauncherError.invalidCustomImage(url))
					return
				}
				await applyDirectCustomArtwork(data: data)
			} catch {
				show(error)
			}
		}
	}

	func resetArtwork() {
		#if DEBUG
			if isDeveloperMode { return }
		#endif
		do {
			if FileManager.default.fileExists(atPath: paths.customArtwork.path) {
				try FileManager.default.removeItem(at: paths.customArtwork)
			}
		} catch {
			show(error)
			return
		}
		guard !isDownloading else { return }
		state.refresh = .idle
		refreshTask?.cancel()
		refreshTask = Task { [weak self] in await self?.refresh() }
	}

	func applyDirectCustomArtwork(data: Data) async {
		guard let image = NSImage(data: data) else {
			show(LauncherError.invalidCustomImage(paths.customArtwork))
			return
		}
		let destination = paths.customArtwork
		do {
			try await Task.detached(priority: .userInitiated) {
				try FileManager.default.createDirectory(
					at: destination.deletingLastPathComponent(),
					withIntermediateDirectories: true
				)
				try data.write(to: destination, options: .atomic)
			}.value
			setHeroArtwork(
				image,
				themeCacheKey: Self.customThemeCacheKey(for: data)
			)
		} catch {
			show(error)
		}
	}

	func loadCustomArtwork() async -> Bool {
		let artworkURL = paths.customArtwork
		guard FileManager.default.fileExists(atPath: artworkURL.path) else { return false }
		do {
			let data = try await Task.detached(priority: .utility) {
				try Data(contentsOf: artworkURL, options: .mappedIfSafe)
			}.value
			guard let image = NSImage(data: data) else {
				Task { [log] in
					await log.error("Custom launcher artwork is not a valid image")
				}
				return false
			}
			setHeroArtwork(image, themeCacheKey: Self.customThemeCacheKey(for: data))
			return true
		} catch {
			Task { [log] in
				await log.error(
					"Failed to load custom launcher artwork: \(error.localizedDescription)"
				)
			}
			return false
		}
	}

	/// Restores local artwork during model construction so SwiftUI's first frame already
	/// has the previous image and cached Dynamic Theme colors. Network refreshes and any
	/// replacement decoding remain asynchronous after the window is visible.
	func restoreInitialArtwork(for region: GameRegion) {
		let hasCustomArtwork = restoreInitialCustomArtwork()
		if !hasCustomArtwork {
			restoreInitialOfficialArtwork(for: region)
		}
		officialLogo = artworkCache.cachedOfficialLogo()
	}

	private func restoreInitialCustomArtwork() -> Bool {
		let artworkURL = paths.customArtwork
		guard FileManager.default.fileExists(atPath: artworkURL.path) else { return false }
		do {
			let data = try Data(contentsOf: artworkURL, options: .mappedIfSafe)
			guard let image = NSImage(data: data) else {
				Task { [log] in
					await log.error("Custom launcher artwork is not a valid image")
				}
				return false
			}
			setHeroArtwork(image, themeCacheKey: Self.customThemeCacheKey(for: data))
			return true
		} catch {
			Task { [log] in
				await log.error(
					"Failed to load custom launcher artwork: \(error.localizedDescription)"
				)
			}
			return false
		}
	}

	private func restoreInitialOfficialArtwork(for region: GameRegion) {
		do {
			guard
				let (cacheKey, data) = try artworkCache.cachedActiveImageData(for: region),
				let image = NSImage(data: data)
			else { return }
			setHeroArtwork(
				image,
				themeCacheKey: Self.officialThemeCacheKey(
					for: region,
					artworkCacheKey: cacheKey
				)
			)
		} catch {
			Task { [log] in
				await log.error(
					"Failed to load cached artwork for \(region.displayName): \(error.localizedDescription)"
				)
			}
		}
	}

	private static func customThemeCacheKey(for data: Data) -> String {
		let digest = SHA256.hash(data: data)
		return "custom.\(digest.map { String(format: "%02x", $0) }.joined())"
	}
}
