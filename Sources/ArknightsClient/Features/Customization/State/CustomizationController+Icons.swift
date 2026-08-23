// SPDX-License-Identifier: MPL-2.0

import AppKit
import Foundation
import UniformTypeIdentifiers

extension CustomizationController {
	func chooseCustomAppIcon() {
		chooseCustomIcon(
			title: LauncherStrings.pickerLauncherIcon,
			apply: applyCustomAppIcon(from:)
		)
	}

	func applyCustomAppIcon(from url: URL) {
		guard let rawImage = NSImage(contentsOf: url) else {
			lifecycle.show(LauncherError.invalidCustomImage(url))
			return
		}
		do {
			try clearOperatorPresetAvatar()
		} catch {
			lifecycle.show(error)
			return
		}
		applyDirectCustomAppIcon(image: AppIconRenderer.padToAppleGrid(image: rawImage))
	}

	func applyDirectCustomAppIcon(image: NSImage) {
		guard let png = encodedIconPNG(image) else {
			lifecycle.show(LauncherError.cannotEncodeAppIcon)
			return
		}
		do {
			try FileManager.default.createDirectory(
				at: paths.customAppIcon.deletingLastPathComponent(),
				withIntermediateDirectories: true
			)
			try png.write(to: paths.customAppIcon)
			guard launcherIconManager.apply(image) else { throw LauncherError.cannotSetAppIcon }
		} catch {
			lifecycle.show(error)
		}
	}

	func chooseCustomGameIcon() {
		chooseCustomIcon(
			title: LauncherStrings.pickerGameIcon,
			apply: applyCustomGameIcon(from:)
		)
	}

	func applyCustomGameIcon(from url: URL) {
		guard let rawImage = NSImage(contentsOf: url) else {
			lifecycle.show(LauncherError.invalidCustomImage(url))
			return
		}
		do {
			try clearOperatorPresetAvatar()
		} catch {
			lifecycle.show(error)
			return
		}
		applyDirectCustomGameIcon(image: AppIconRenderer.padToAppleGrid(image: rawImage))
	}

	func applyDirectCustomGameIcon(image: NSImage) {
		guard let png = encodedIconPNG(image) else {
			lifecycle.show(LauncherError.cannotEncodeAppIcon)
			return
		}
		do {
			try FileManager.default.createDirectory(
				at: paths.customGameIcon.deletingLastPathComponent(),
				withIntermediateDirectories: true
			)
			try png.write(to: paths.customGameIcon, options: .atomic)
			lifecycle.setStatus(.custom(L10n.string(.Launcher.launcherStatusGameIconUpdated)))
		} catch {
			lifecycle.show(error)
		}
	}

	func applyPresetAvatar(data: Data) {
		guard
			let icons = AppIconRenderer.createPresetIconPair(
				from: data, accentHue: dynamicThemeHue),
			let launcherPNG = encodedIconPNG(icons.launcher),
			let gamePNG = encodedIconPNG(icons.game)
		else {
			lifecycle.show(LauncherError.cannotEncodeAppIcon)
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
			lifecycle.setStatus(.custom(L10n.string(.Launcher.launcherStatusIconsUpdated)))
		} catch {
			lifecycle.show(error)
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
			lifecycle.setStatus(.custom(L10n.string(.Launcher.launcherStatusGameIconRestored)))
		} catch {
			lifecycle.show(error)
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
			guard launcherIconManager.reset() else { throw LauncherError.cannotSetAppIcon }
			updateThemeColor()
		} catch {
			lifecycle.show(error)
		}
	}

	@discardableResult
	func loadCustomAppIcon() async -> Bool {
		let iconURL = paths.customAppIcon
		guard FileManager.default.fileExists(atPath: iconURL.path) else { return false }
		do {
			let data = try await Task.detached(priority: .utility) {
				try Data(contentsOf: iconURL, options: .mappedIfSafe)
			}.value
			guard let image = NSImage(data: data) else {
				await log.error("Saved launcher icon is not a valid image")
				return false
			}
			if !launcherIconManager.apply(image) {
				await log.error("Failed to reapply the saved launcher icon to the app bundle")
			}
			return true
		} catch {
			await log.error("Failed to load saved launcher icon: \(error.localizedDescription)")
			return false
		}
	}

	func resetOperatorIcons() {
		do {
			for url in [paths.customAppIcon, paths.customGameIcon, paths.operatorPresetAvatar]
			where FileManager.default.fileExists(atPath: url.path) {
				try FileManager.default.removeItem(at: url)
			}
			guard launcherIconManager.reset() else { throw LauncherError.cannotSetAppIcon }
			updateThemeColor()
			lifecycle.setStatus(.custom(L10n.string(.Launcher.launcherStatusIconsRestored)))
		} catch {
			lifecycle.show(error)
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

	private func chooseCustomIcon(
		title: LocalizedStringResource,
		apply: @escaping (URL) -> Void
	) {
		let panel = NSOpenPanel()
		panel.title = L10n.string(title)
		panel.prompt = L10n.string(LauncherStrings.pickerChoose)
		panel.allowedContentTypes = [.image]
		panel.canChooseDirectories = false
		panel.canChooseFiles = true
		panel.allowsMultipleSelection = false
		guard panel.runModal() == .OK, let selected = panel.url else { return }
		apply(selected)
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
