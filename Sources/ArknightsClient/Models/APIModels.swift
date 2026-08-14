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
