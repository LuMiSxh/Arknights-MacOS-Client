// SPDX-License-Identifier: MPL-2.0

import Foundation

struct APIEnvelope<Value: Decodable>: Decodable {
	let code: Int
	let data: Value
	let msg: String?
}

struct GameConfiguration: Codable, Sendable {
	let gameLowestVersion: String
	let gameLatestVersion: String
	let gameLatestFilePath: String
	let gameStartExeName: String
	let gameStartParams: [String]
	let gameUninstallScript: String
	let decompressionSize: String

	var executableName: String {
		gameStartExeName.lowercased().hasSuffix(".exe")
			? gameStartExeName
			: "\(gameStartExeName).exe"
	}

	/// Yostar's own reported install footprint (e.g. "30GB"), which already covers the
	/// game's post-launch asset downloads that this launcher's manifest doesn't see.
	var requiredInstallBytes: Int64? {
		Self.parseByteSize(decompressionSize)
	}

	static func parseByteSize(_ text: String) -> Int64? {
		let trimmed = text.trimmingCharacters(in: .whitespaces).uppercased()
		let digits = trimmed.prefix(while: { $0.isNumber || $0 == "." })
		guard let value = Double(digits) else { return nil }
		let unit = String(trimmed.dropFirst(digits.count)).trimmingCharacters(in: .whitespaces)
		let multiplier: Double
		switch unit {
		case "TB": multiplier = 1_000_000_000_000
		case "GB", "": multiplier = 1_000_000_000
		case "MB": multiplier = 1_000_000
		case "KB": multiplier = 1_000
		default: return nil
		}
		return Int64(value * multiplier)
	}
}

struct CDNConfiguration: Codable, Sendable {
	let primaryCdn: URL
	let backUpCdn: URL
}

struct ManifestLocation: Codable, Sendable {
	let url: URL
}

struct GameManifest: Codable, Sendable {
	let source: String
	let file: [ManifestFile]
}

struct ManifestFile: Codable, Hashable, Sendable {
	let path: String
	let hash: String
	let size: String

	var byteCount: Int64 {
		Int64(size) ?? 0
	}
}
