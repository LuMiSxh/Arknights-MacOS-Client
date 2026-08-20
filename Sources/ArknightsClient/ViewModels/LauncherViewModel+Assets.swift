// SPDX-License-Identifier: MPL-2.0

import AppKit
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
			try clearPresetAvatar(for: .launcherIcon)
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
			try clearPresetAvatar(for: .gameIcon)
		} catch {
			show(error)
			return
		}
		applyDirectCustomGameIcon(image: AppIconRenderer.padToAppleGrid(image: rawImage))
	}

	func applyPresetAvatar(data: Data, to destination: PresetGalleryDestination) {
		guard destination != .artwork,
			let icon = AppIconRenderer.createAvatarIcon(
				from: data,
				style: avatarIconStyle,
				accentHue: dynamicThemeHue
			)
		else {
			show(LauncherError.cannotEncodeAppIcon)
			return
		}

		do {
			let sourceURL = presetAvatarSourceURL(for: destination)
			try FileManager.default.createDirectory(
				at: sourceURL.deletingLastPathComponent(),
				withIntermediateDirectories: true
			)
			try data.write(to: sourceURL, options: .atomic)
			preferences.setPresetIconStyle(avatarIconStyle, for: destination)
			if destination == .gameIcon {
				applyDirectCustomGameIcon(image: icon)
			} else {
				applyDirectCustomAppIcon(image: icon)
			}
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
			try clearPresetAvatar(for: .gameIcon)
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
			heroArtwork = NSImage(data: data)
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
			try clearPresetAvatar(for: .launcherIcon)
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
		guard let image = NSImage(contentsOf: paths.customArtwork) else { return false }
		heroArtwork = image
		return true
	}

	func refreshPresetIconsForTheme(hue: Double?) async {
		for destination in [PresetGalleryDestination.launcherIcon, .gameIcon] {
			guard preferences.presetIconStyle(for: destination) == .launcherGlass else {
				continue
			}
			let sourceURL = presetAvatarSourceURL(for: destination)
			do {
				let data = try await Task.detached(priority: .utility) {
					try Data(contentsOf: sourceURL)
				}.value
				guard
					let icon = AppIconRenderer.createAvatarIcon(
						from: data,
						style: .launcherGlass,
						accentHue: hue
					),
					let png = encodedIconPNG(icon)
				else { throw LauncherError.cannotEncodeAppIcon }
				let iconURL = destination == .gameIcon ? paths.customGameIcon : paths.customAppIcon
				try png.write(to: iconURL, options: .atomic)
				if destination == .launcherIcon {
					NSApp?.applicationIconImage = icon
				}
			} catch {
				await log.error(
					"Failed to refresh the \(destination.rawValue) preset icon for Dynamic Theme: \(error.localizedDescription)"
				)
			}
		}
	}

	private func encodedIconPNG(_ image: NSImage) -> Data? {
		guard let tiff = image.tiffRepresentation,
			let representation = NSBitmapImageRep(data: tiff)
		else { return nil }
		return representation.representation(using: .png, properties: [:])
	}

	private func presetAvatarSourceURL(for destination: PresetGalleryDestination) -> URL {
		destination == .gameIcon ? paths.gamePresetAvatar : paths.launcherPresetAvatar
	}

	private func clearPresetAvatar(for destination: PresetGalleryDestination) throws {
		let sourceURL = presetAvatarSourceURL(for: destination)
		if FileManager.default.fileExists(atPath: sourceURL.path) {
			try FileManager.default.removeItem(at: sourceURL)
		}
		preferences.setPresetIconStyle(nil, for: destination)
	}
}
