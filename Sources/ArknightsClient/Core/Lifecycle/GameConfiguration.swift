// SPDX-License-Identifier: MPL-2.0

import Foundation

struct GameConfiguration: Codable, Sendable {
	let gameLowestVersion: String
	let gameLatestVersion: String
	let gameLatestFilePath: String
	let gameStartExeName: String
	let gameStartParams: [String]
	let gameUninstallScript: String
	let decompressionSize: String

	init(
		gameLowestVersion: String,
		gameLatestVersion: String,
		gameLatestFilePath: String,
		gameStartExeName: String,
		gameStartParams: [String],
		gameUninstallScript: String,
		decompressionSize: String
	) {
		self.gameLowestVersion = gameLowestVersion
		self.gameLatestVersion = gameLatestVersion
		self.gameLatestFilePath = gameLatestFilePath
		self.gameStartExeName = gameStartExeName
		self.gameStartParams = gameStartParams
		self.gameUninstallScript = gameUninstallScript
		self.decompressionSize = decompressionSize
	}

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
		let numberEnd = trimmed.firstIndex(where: { !$0.isNumber && $0 != "." }) ?? trimmed.endIndex
		let number = String(trimmed[..<numberEnd])
		let unit = String(trimmed[numberEnd...]).trimmingCharacters(in: .whitespaces)
		guard
			number.first?.isNumber == true,
			number.last?.isNumber == true,
			number.filter({ $0 == "." }).count <= 1,
			let value = Double(number),
			value.isFinite,
			value >= 0
		else { return nil }
		let multiplier: Double
		switch unit {
		case "TB": multiplier = 1_000_000_000_000
		case "GB", "": multiplier = 1_000_000_000
		case "MB": multiplier = 1_000_000
		case "KB": multiplier = 1_000
		default: return nil
		}
		let bytes = value * multiplier
		guard bytes.isFinite, bytes < Double(Int64.max) else { return nil }
		return Int64(bytes.rounded(.towardZero))
	}

	private enum CodingKeys: String, CodingKey {
		case gameLowestVersion
		case gameLatestVersion
		case gameLatestFilePath
		case gameStartExeName
		case gameStartParams
		case gameUninstallScript
		case decompressionSize
	}

	init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		gameLowestVersion = try container.decode(String.self, forKey: .gameLowestVersion)
		gameLatestVersion = try container.decode(String.self, forKey: .gameLatestVersion)
		gameLatestFilePath = try container.decode(String.self, forKey: .gameLatestFilePath)
		let executable = try container.decode(String.self, forKey: .gameStartExeName)
		guard Self.isSafeExecutableBasename(executable) else {
			throw DecodingError.dataCorruptedError(
				forKey: .gameStartExeName, in: container,
				debugDescription: "gameStartExeName must be a non-empty executable basename")
		}
		gameStartExeName = executable
		gameStartParams = try container.decode([String].self, forKey: .gameStartParams)
		gameUninstallScript = try container.decode(String.self, forKey: .gameUninstallScript)
		let size = try container.decode(String.self, forKey: .decompressionSize)
		guard Self.parseByteSize(size) != nil else {
			throw DecodingError.dataCorruptedError(
				forKey: .decompressionSize, in: container,
				debugDescription: "decompressionSize must be a finite, non-negative byte size")
		}
		decompressionSize = size
	}

	private static func isSafeExecutableBasename(_ value: String) -> Bool {
		!value.isEmpty && value != "." && value != ".."
			&& !value.contains { $0 == "/" || $0 == "\\" || $0.isNewline || $0.asciiValue == 0 }
	}
}
