// SPDX-License-Identifier: MPL-2.0

import Foundation

struct APIEnvelope<Value: Decodable>: Decodable {
	let code: Int
	let data: Value
	let msg: String?
}

struct CDNConfiguration: Codable, Sendable {
	let primaryCdn: URL
	let backUpCdn: URL
}

struct ManifestLocation: Codable, Sendable {
	let url: URL
}

struct GameManifest: Codable, Sendable {
	static let maximumFileByteCount: Int64 = 1_099_511_627_776
	static let maximumTotalByteCount: Int64 = 4_398_046_511_104

	let source: String
	let file: [ManifestFile]
}

struct ManifestFile: Codable, Hashable, Sendable {
	let path: String
	let hash: String
	let byteCount: Int64

	var size: String { String(byteCount) }

	init(path: String, hash: String, size: String) {
		guard let byteCount = Self.canonicalByteCount(size) else {
			preconditionFailure("Manifest numeric fields must be canonical decimal values")
		}
		self.path = path
		self.hash = hash
		self.byteCount = byteCount
	}

	private enum CodingKeys: String, CodingKey {
		case path, hash, size
	}

	init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		path = try container.decode(String.self, forKey: .path)
		let hash = try container.decode(String.self, forKey: .hash)
		let size = try container.decode(String.self, forKey: .size)
		guard let byteCount = Self.canonicalByteCount(size) else {
			throw DecodingError.dataCorruptedError(
				forKey: .size, in: container,
				debugDescription: "Manifest numeric fields must be canonical decimal values")
		}
		self.hash = hash
		self.byteCount = byteCount
	}

	func encode(to encoder: any Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(path, forKey: .path)
		try container.encode(hash, forKey: .hash)
		try container.encode(size, forKey: .size)
	}

	private static func canonicalByteCount(_ value: String) -> Int64? {
		guard let parsed = Int64(value), parsed >= 0, String(parsed) == value else { return nil }
		return parsed
	}
}
