// SPDX-License-Identifier: MPL-2.0

import AppKit
import Foundation
import UniformTypeIdentifiers

extension LauncherViewModel {
	/// Keeps an Application Support copy for updates, then delegates every macOS icon surface
	/// to `LauncherIconManager`; the running-process icon itself resets between launches.
	func chooseCustomAppIcon() {
		let panel = NSOpenPanel()
		panel.title = L10n.string(LauncherStrings.pickerLauncherIcon)
		panel.prompt = L10n.string(LauncherStrings.pickerChoose)
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
			guard launcherIconManager.apply(image) else {
				throw LauncherError.cannotSetAppIcon
			}
		} catch {
			show(error)
		}
	}

	func chooseCustomGameIcon() {
		let panel = NSOpenPanel()
		panel.title = L10n.string(LauncherStrings.pickerGameIcon)
		panel.prompt = L10n.string(LauncherStrings.pickerChoose)
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
			guard launcherIconManager.apply(icons.launcher) else {
				throw LauncherError.cannotSetAppIcon
			}
			try data.write(to: sourceURL, options: .atomic)
			setStatus(.custom(L10n.string(.Launcher.launcherStatusIconsUpdated)))
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
			setStatus(.custom(L10n.string(.Launcher.launcherStatusGameIconUpdated)))
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
			setStatus(.custom(L10n.string(.Launcher.launcherStatusGameIconRestored)))
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
			guard launcherIconManager.reset() else {
				throw LauncherError.cannotSetAppIcon
			}
			updateThemeColor()
		} catch {
			show(error)
		}
	}

	@discardableResult
	func loadCustomAppIcon() async -> Bool {
		let iconURL = paths.customAppIcon
		guard FileManager.default.fileExists(atPath: iconURL.path) else { return false }
		let data: Data
		do {
			data = try await Task.detached(priority: .utility) {
				try Data(contentsOf: iconURL, options: .mappedIfSafe)
			}.value
		} catch {
			await log.error("Failed to load saved launcher icon: \(error.localizedDescription)")
			return false
		}
		guard let image = NSImage(data: data) else {
			await log.error("Saved launcher icon is not a valid image")
			return false
		}
		if !launcherIconManager.apply(image) {
			Task { [log] in
				await log.error(
					"Failed to reapply the saved launcher icon to the app bundle"
				)
			}
		}
		return true
	}

	func resetOperatorIcons() {
		do {
			for url in [paths.customAppIcon, paths.customGameIcon, paths.operatorPresetAvatar]
			where FileManager.default.fileExists(atPath: url.path) {
				try FileManager.default.removeItem(at: url)
			}
			guard launcherIconManager.reset() else {
				throw LauncherError.cannotSetAppIcon
			}
			updateThemeColor()
			setStatus(.custom(L10n.string(.Launcher.launcherStatusIconsRestored)))
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
			guard launcherIconManager.apply(icons.launcher) else {
				throw LauncherError.cannotSetAppIcon
			}
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
