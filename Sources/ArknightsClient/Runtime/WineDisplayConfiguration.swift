// SPDX-License-Identifier: MPL-2.0

import AppKit
import Foundation

struct WineDisplayConfiguration: Equatable, Sendable {
	static let forceDisablePreference = "forceDisableRetina"

	let retinaEnabled: Bool

	init(
		backingScaleFactor: CGFloat,
		highResolutionEnabled: Bool = true,
		forceDisabled: Bool = false
	) {
		retinaEnabled = backingScaleFactor > 1 && highResolutionEnabled && !forceDisabled
	}

	@MainActor
	static func current(
		highResolutionEnabled: Bool,
		arguments: [String] = ProcessInfo.processInfo.arguments,
		defaults: UserDefaults = .standard
	) -> WineDisplayConfiguration {
		let scale =
			NSApp.keyWindow?.screen?.backingScaleFactor
			?? NSScreen.main?.backingScaleFactor
			?? 1
		let forceDisabled =
			arguments.contains("--no-retina")
			|| defaults.bool(forKey: forceDisablePreference)
		return WineDisplayConfiguration(
			backingScaleFactor: scale,
			highResolutionEnabled: highResolutionEnabled,
			forceDisabled: forceDisabled
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
		for line in contents.split(separator: "\n", omittingEmptySubsequences: false) {
			if line.hasPrefix("[") {
				section = String(line)
				continue
			}
			if section == macDriverSection && line.hasPrefix("\"RetinaMode\"=\"") {
				retinaMode = line.dropFirst(14).dropLast().lowercased()
			}
			if section == desktopSection && line.hasPrefix("\"LogPixels\"=dword:") {
				configuredLogPixels = Int(line.dropFirst(18), radix: 16)
			}
		}
		return WineDisplayRegistryState(
			retinaMode: retinaMode,
			logPixels: configuredLogPixels
		)
	}
}

struct WineDisplayRegistryState: Equatable, Sendable {
	let retinaMode: String?
	let logPixels: Int?
}
