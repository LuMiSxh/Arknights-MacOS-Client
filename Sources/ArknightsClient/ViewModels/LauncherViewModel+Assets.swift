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
		do {
			try FileManager.default.createDirectory(
				at: paths.customArtwork.deletingLastPathComponent(),
				withIntermediateDirectories: true
			)
			if FileManager.default.fileExists(atPath: paths.customArtwork.path) {
				try FileManager.default.removeItem(at: paths.customArtwork)
			}
			try FileManager.default.copyItem(at: url, to: paths.customArtwork)
			applyDirectCustomArtwork(data: try Data(contentsOf: paths.customArtwork))
		} catch {
			show(error)
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
		activeRefreshID = nil
		refreshTask?.cancel()
		refreshTask = Task { [weak self] in await self?.refresh() }
	}

	/// Persists via `NSWorkspace.setIcon`, a Finder extended attribute on the app bundle
	/// untouched by code signing, plus our own copy so the Dock icon can be reapplied on
	/// the next launch (`NSApp.applicationIconImage` itself resets every launch).
	func chooseCustomAppIcon() {
		let panel = NSOpenPanel()
		panel.title = "Choose an app icon"
		panel.prompt = "Choose"
		panel.allowedContentTypes = [.image]
		panel.canChooseDirectories = false
		panel.canChooseFiles = true
		panel.allowsMultipleSelection = false
		guard panel.runModal() == .OK, let selected = panel.url else { return }
		applyCustomAppIcon(from: selected)
	}

	func applyCustomAppIcon(from url: URL) {
		guard let rawImage = NSImage(contentsOf: url) else {
			show(LauncherError.invalidCustomImage(url))
			return
		}
		do {
			try clearOperatorPresetAvatar()
		} catch {
			show(error)
			return
		}
		applyDirectCustomAppIcon(image: AppIconRenderer.padToAppleGrid(image: rawImage))
	}

	func applyDirectCustomAppIcon(image: NSImage) {
		guard let png = encodedIconPNG(image) else {
			show(LauncherError.cannotEncodeAppIcon)
			return
		}

		do {
			try FileManager.default.createDirectory(
				at: paths.customAppIcon.deletingLastPathComponent(),
				withIntermediateDirectories: true
			)
			try png.write(to: paths.customAppIcon)
			guard
				NSWorkspace.shared.setIcon(
					image,
					forFile: Bundle.main.bundlePath,
					options: []
				)
			else {
				throw LauncherError.cannotSetAppIcon
			}
			NSApp?.applicationIconImage = image
		} catch {
			show(error)
		}
	}

	func chooseCustomGameIcon() {
		let panel = NSOpenPanel()
		panel.title = "Choose a game icon"
		panel.prompt = "Choose"
		panel.allowedContentTypes = [.image]
		panel.canChooseDirectories = false
		panel.canChooseFiles = true
		panel.allowsMultipleSelection = false
		guard panel.runModal() == .OK, let selected = panel.url else { return }
		applyCustomGameIcon(from: selected)
	}

	func applyCustomGameIcon(from url: URL) {
		guard let rawImage = NSImage(contentsOf: url) else {
			show(LauncherError.invalidCustomImage(url))
			return
		}
		do {
			try clearOperatorPresetAvatar()
		} catch {
			show(error)
			return
		}
		applyDirectCustomGameIcon(image: AppIconRenderer.padToAppleGrid(image: rawImage))
	}

	func applyPresetAvatar(data: Data) {
		guard
			let icons = AppIconRenderer.createPresetIconPair(
				from: data, accentHue: dynamicThemeHue
			),
			let launcherPNG = encodedIconPNG(icons.launcher),
			let gamePNG = encodedIconPNG(icons.game)
		else {
			show(LauncherError.cannotEncodeAppIcon)
			return
		}

		do {
			let sourceURL = paths.operatorPresetAvatar
			try FileManager.default.createDirectory(
				at: sourceURL.deletingLastPathComponent(),
				withIntermediateDirectories: true
			)
			try launcherPNG.write(to: paths.customAppIcon, options: .atomic)
			try gamePNG.write(to: paths.customGameIcon, options: .atomic)
			guard
				NSWorkspace.shared.setIcon(
					icons.launcher,
					forFile: Bundle.main.bundlePath,
					options: []
				)
			else { throw LauncherError.cannotSetAppIcon }
			try data.write(to: sourceURL, options: .atomic)
			NSApp?.applicationIconImage = icons.launcher
			activityMessage = "Launcher and game icons updated"
		} catch {
			show(error)
		}
	}

	func applyDirectCustomGameIcon(image: NSImage) {
		guard let png = encodedIconPNG(image) else {
			show(LauncherError.cannotEncodeAppIcon)
			return
		}
		do {
			try FileManager.default.createDirectory(
				at: paths.customGameIcon.deletingLastPathComponent(),
				withIntermediateDirectories: true
			)
			try png.write(to: paths.customGameIcon, options: .atomic)
			activityMessage = "Game icon updated for the next launch"
		} catch {
			show(error)
		}
	}

	var hasCustomGameIcon: Bool {
		FileManager.default.fileExists(atPath: paths.customGameIcon.path)
	}

	func resetGameIcon() {
		do {
			if FileManager.default.fileExists(atPath: paths.customGameIcon.path) {
				try FileManager.default.removeItem(at: paths.customGameIcon)
			}
			try clearOperatorPresetAvatar()
			activityMessage = "Default game icon restored for the next launch"
		} catch {
			show(error)
		}
	}

	func applyDirectCustomArtwork(data: Data) {
		do {
			try FileManager.default.createDirectory(
				at: paths.customArtwork.deletingLastPathComponent(),
				withIntermediateDirectories: true
			)
			try data.write(to: paths.customArtwork)
			if let image = NSImage(data: data) {
				setHeroArtwork(
					image,
					themeCacheKey: Self.customThemeCacheKey(for: data)
				)
			}
		} catch {
			show(error)
		}
	}

	var hasCustomAppIcon: Bool {
		FileManager.default.fileExists(atPath: paths.customAppIcon.path)
	}

	func resetAppIcon() {
		do {
			if FileManager.default.fileExists(atPath: paths.customAppIcon.path) {
				try FileManager.default.removeItem(at: paths.customAppIcon)
			}
			try clearOperatorPresetAvatar()
			guard
				NSWorkspace.shared.setIcon(
					nil,
					forFile: Bundle.main.bundlePath,
					options: []
				)
			else {
				throw LauncherError.cannotSetAppIcon
			}
			NSApp?.applicationIconImage = nil
			updateThemeColor()
		} catch {
			show(error)
		}
	}

	@discardableResult
	func loadCustomAppIcon() -> Bool {
		guard let image = NSImage(contentsOf: paths.customAppIcon) else { return false }
		NSApp?.applicationIconImage = image
		return true
	}

	func loadCustomArtwork() -> Bool {
		guard FileManager.default.fileExists(atPath: paths.customArtwork.path) else { return false }
		do {
			let data = try Data(contentsOf: paths.customArtwork, options: .mappedIfSafe)
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

	private static func customThemeCacheKey(for data: Data) -> String {
		let digest = SHA256.hash(data: data)
		return "custom.\(digest.map { String(format: "%02x", $0) }.joined())"
	}

	func resetOperatorIcons() {
		do {
			for url in [paths.customAppIcon, paths.customGameIcon, paths.operatorPresetAvatar]
			where FileManager.default.fileExists(atPath: url.path) {
				try FileManager.default.removeItem(at: url)
			}
			guard NSWorkspace.shared.setIcon(nil, forFile: Bundle.main.bundlePath, options: [])
			else { throw LauncherError.cannotSetAppIcon }
			NSApp?.applicationIconImage = nil
			updateThemeColor()
			activityMessage = "Default Launcher and game icons restored"
		} catch {
			show(error)
		}
	}

	func refreshOperatorPresetIconsForTheme(hue: Double?) async {
		let sourceURL = paths.operatorPresetAvatar
		guard FileManager.default.fileExists(atPath: sourceURL.path) else { return }
		do {
			let data = try await Task.detached(priority: .utility) {
				try Data(contentsOf: sourceURL)
			}.value
			guard
				let icons = AppIconRenderer.createPresetIconPair(from: data, accentHue: hue),
				let launcherPNG = encodedIconPNG(icons.launcher),
				let gamePNG = encodedIconPNG(icons.game)
			else { throw LauncherError.cannotEncodeAppIcon }
			try launcherPNG.write(to: paths.customAppIcon, options: .atomic)
			try gamePNG.write(to: paths.customGameIcon, options: .atomic)
			NSApp?.applicationIconImage = icons.launcher
		} catch {
			await log.error(
				"Failed to refresh operator icons for Dynamic Theme: \(error.localizedDescription)"
			)
		}
	}

	private func encodedIconPNG(_ image: NSImage) -> Data? {
		guard let tiff = image.tiffRepresentation,
			let representation = NSBitmapImageRep(data: tiff)
		else { return nil }
		return representation.representation(using: .png, properties: [:])
	}

	private func clearOperatorPresetAvatar() throws {
		let sourceURL = paths.operatorPresetAvatar
		if FileManager.default.fileExists(atPath: sourceURL.path) {
			try FileManager.default.removeItem(at: sourceURL)
		}
	}
}
