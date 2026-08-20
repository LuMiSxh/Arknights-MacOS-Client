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
		applyDirectCustomAppIcon(image: AppIconRenderer.padToAppleGrid(image: rawImage))
	}

	func applyDirectCustomAppIcon(image: NSImage) {
		guard let tiff = image.tiffRepresentation,
			let representation = NSBitmapImageRep(data: tiff),
			let png = representation.representation(using: .png, properties: [:])
		else {
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
}
