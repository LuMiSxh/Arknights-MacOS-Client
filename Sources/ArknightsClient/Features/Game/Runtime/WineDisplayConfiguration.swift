// SPDX-License-Identifier: MPL-2.0

import AppKit
import Foundation

/// Whether to run the game and its login browser at full backing-store resolution, derived
/// from the current screen's scale factor, the selected rendering mode, and a `--no-retina`
/// override. MetalFX keeps Wine's point-sized surfaces and lets DXMT multiply the layer's
/// content scale, so its default 2x factor reaches the backing store; a runtime without
/// MetalFX support falls back to Lightweight rendering.
struct WineDisplayConfiguration: Equatable, Sendable {
	let retinaEnabled: Bool
	let metalFXUpscalingEnabled: Bool
	/// Game pixels per macOS point, used to turn a window size into a Unity resolution.
	let gamePixelsPerPoint: Int

	init(
		backingScaleFactor: CGFloat,
		renderingMode: GameRenderingMode = .retina,
		forceDisabled: Bool = false,
		metalFXSupported: Bool = false
	) {
		let usesBackingStore = backingScaleFactor > 1 && !forceDisabled
		metalFXUpscalingEnabled = usesBackingStore && renderingMode == .metalFX && metalFXSupported
		retinaEnabled = usesBackingStore && renderingMode == .retina
		gamePixelsPerPoint = retinaEnabled ? max(1, Int(backingScaleFactor.rounded())) : 1
	}

	@MainActor
	static func current(
		renderingMode: GameRenderingMode,
		arguments: [String] = ProcessInfo.processInfo.arguments,
		forceDisabled: Bool = false,
		metalFXSupported: Bool = false
	) -> WineDisplayConfiguration {
		let scale =
			NSApp.keyWindow?.screen?.backingScaleFactor
			?? NSScreen.main?.backingScaleFactor
			?? 1
		return WineDisplayConfiguration(
			backingScaleFactor: scale,
			renderingMode: renderingMode,
			forceDisabled: forceDisabled || arguments.contains("--no-retina"),
			metalFXSupported: metalFXSupported
		)
	}

	var registryValue: String { retinaEnabled ? "y" : "n" }
	var logPixels: Int { 96 }
	var browserScaleFactor: Int { retinaEnabled ? 2 : 1 }

	func registryState(in prefixDirectory: URL) -> WineDisplayRegistryState? {
		let registryURL = prefixDirectory.appending(path: "user.reg")
		guard
			let contents = try? String(contentsOf: registryURL, encoding: .utf8)
		else { return nil }

		let macDriverSection = "[Software\\\\Wine\\\\Mac Driver]"
		let desktopSection = "[Control Panel\\\\Desktop]"
		var section = ""
		var retinaMode: String?
		var configuredLogPixels: Int?
		var usePreciseScrolling: String?
		for line in contents.split(separator: "\n", omittingEmptySubsequences: false) {
			if line.hasPrefix("["), let closingBracket = line.firstIndex(of: "]") {
				section = String(line[...closingBracket])
				continue
			}
			if section == macDriverSection && line.hasPrefix("\"RetinaMode\"=\"") {
				retinaMode = line.dropFirst(14).dropLast().lowercased()
			}
			if section == macDriverSection && line.hasPrefix("\"UsePreciseScrolling\"=\"") {
				usePreciseScrolling = String(line.dropFirst(23).dropLast().lowercased())
			}
			if section == desktopSection && line.hasPrefix("\"LogPixels\"=dword:") {
				configuredLogPixels = Int(line.dropFirst(18), radix: 16)
			}
		}
		return WineDisplayRegistryState(
			retinaMode: retinaMode,
			logPixels: configuredLogPixels,
			usePreciseScrolling: usePreciseScrolling
		)
	}
}

struct WineDisplayRegistryState: Equatable, Sendable {
	let retinaMode: String?
	let logPixels: Int?
	let usePreciseScrolling: String?
}
