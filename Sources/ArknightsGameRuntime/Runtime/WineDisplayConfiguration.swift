// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation

// Whether to run the game and its login browser at full backing-store resolution, derived
// from the current screen's scale factor, the selected rendering mode, and a `--no-retina`
// override. MetalFX keeps Wine's point-sized surfaces and lets DXMT multiply the layer's
// content scale, so its default 2x factor reaches the backing store; a runtime without
// MetalFX support falls back to Standard rendering.
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

	static func current(
		renderingMode: GameRenderingMode,
		backingScaleFactor: CGFloat,
		arguments: [String] = ProcessInfo.processInfo.arguments,
		metalFXSupported: Bool = false
	) -> WineDisplayConfiguration {
		return WineDisplayConfiguration(
			backingScaleFactor: backingScaleFactor,
			renderingMode: renderingMode,
			forceDisabled: arguments.contains("--no-retina"),
			metalFXSupported: metalFXSupported
		)
	}

	var registryValue: String { retinaEnabled ? "y" : "n" }
	var logPixels: Int { 96 }
	var browserScaleFactor: Int { retinaEnabled ? 2 : 1 }

	func registryState(
		in prefixDirectory: URL,
		log: LauncherLog? = nil
	) -> WineDisplayRegistryState? {
		let registryURL = prefixDirectory.appending(path: "user.reg")
		// A prefix that Wine has not initialized has no user.reg yet. That is not an error.
		guard FileManager.default.fileExists(atPath: registryURL.path) else { return nil }
		let contents: String
		do {
			contents = try String(contentsOf: registryURL, encoding: .utf8)
		} catch {
			log?.error(.prefix, "user-reg-read-failed", error: error)
			return nil
		}

		let macDriverSection = "[Software\\\\Wine\\\\Mac Driver]"
		let desktopSection = "[Control Panel\\\\Desktop]"
		let retinaModePrefix = "\"RetinaMode\"=\""
		let preciseScrollingPrefix = "\"UsePreciseScrolling\"=\""
		let logPixelsPrefix = "\"LogPixels\"=dword:"
		var section = ""
		var retinaMode: Bool?
		var configuredLogPixels: Int?
		var usePreciseScrolling: Bool?
		for line in contents.split(separator: "\n", omittingEmptySubsequences: false) {
			if line.hasPrefix("["), let closingBracket = line.firstIndex(of: "]") {
				section = String(line[...closingBracket])
				continue
			}
			if section == macDriverSection, line.hasPrefix(retinaModePrefix) {
				retinaMode = Self.registryBool(line.dropFirst(retinaModePrefix.count).dropLast())
			}
			if section == macDriverSection, line.hasPrefix(preciseScrollingPrefix) {
				usePreciseScrolling = Self.registryBool(
					line.dropFirst(preciseScrollingPrefix.count).dropLast())
			}
			if section == desktopSection, line.hasPrefix(logPixelsPrefix) {
				configuredLogPixels = Int(line.dropFirst(logPixelsPrefix.count), radix: 16)
			}
		}
		return WineDisplayRegistryState(
			retinaMode: retinaMode,
			logPixels: configuredLogPixels,
			usePreciseScrolling: usePreciseScrolling
		)
	}

	// Wine stores these values as the quoted strings "y" and "n".
	private static func registryBool(_ value: Substring) -> Bool? {
		switch value.lowercased() {
		case "y": true
		case "n": false
		default: nil
		}
	}
}

struct WineDisplayRegistryState: Equatable, Sendable {
	let retinaMode: Bool?
	let logPixels: Int?
	let usePreciseScrolling: Bool?
}
