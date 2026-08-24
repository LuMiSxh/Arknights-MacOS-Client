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
		Task { [weak self] in
			guard let self else { return }
			do {
				let data = try await Task.detached(priority: .userInitiated) {
					try Data(contentsOf: url, options: .mappedIfSafe)
				}.value
				guard NSImage(data: data) != nil else {
					lifecycle.show(LauncherError.invalidCustomImage(url))
					return
				}
				await applyDirectCustomArtwork(data: data)
			} catch {
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
		customArtworkDidChange()
		guard !isDownloading else { return }
		lifecycle.refresh = .idle
		restartRefresh()
	}

	func applyDirectCustomArtwork(data: Data) async {
		guard let image = NSImage(data: data) else {
			lifecycle.show(LauncherError.invalidCustomImage(paths.customArtwork))
			return
		}
		let destination = paths.customArtwork
		customArtworkDidChange()
		do {
			try await Task.detached(priority: .userInitiated) {
				try FileManager.default.createDirectory(
					at: destination.deletingLastPathComponent(),
					withIntermediateDirectories: true
				)
				try data.write(to: destination, options: .atomic)
			}.value
			setHeroArtwork(image, themeCacheKey: Self.customThemeCacheKey(for: data))
		} catch {
			lifecycle.show(error)
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
				await log.error("Custom launcher artwork is not a valid image")
				return false
			}
			setHeroArtwork(image, themeCacheKey: Self.customThemeCacheKey(for: data))
			return true
		} catch {
			await log.error("Failed to load custom launcher artwork: \(error.localizedDescription)")
			return false
		}
	}

	/// Restores local artwork before the first SwiftUI frame, keeping cached Dynamic Theme colors
	/// available while the active region refreshes in the background.
	func restoreInitialArtwork(for region: GameRegion) {
		let hasCustomArtwork = restoreInitialCustomArtwork()
		if !hasCustomArtwork {
			restoreInitialOfficialArtwork(for: region)
		}
		officialLogo = artworkCache.cachedOfficialLogo(for: region)
	}

	/// Clears any previous region's wordmark before a refresh can load the selected region's asset.
	func restoreOfficialLogo(for region: GameRegion) {
		officialLogo = artworkCache.cachedOfficialLogo(for: region)
	}

	private func restoreInitialCustomArtwork() -> Bool {
		let artworkURL = paths.customArtwork
		guard FileManager.default.fileExists(atPath: artworkURL.path) else { return false }
		do {
			let data = try Data(contentsOf: artworkURL, options: .mappedIfSafe)
			guard let image = NSImage(data: data) else {
				Task { [log] in await log.error("Custom launcher artwork is not a valid image") }
				return false
			}
			setHeroArtwork(image, themeCacheKey: Self.customThemeCacheKey(for: data))
			return true
		} catch {
			Task { [log] in
				await log.error(
					"Failed to load custom launcher artwork: \(error.localizedDescription)")
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
				themeCacheKey: Self.officialThemeCacheKey(for: region, artworkCacheKey: cacheKey)
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
