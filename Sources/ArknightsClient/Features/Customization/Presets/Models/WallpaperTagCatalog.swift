// SPDX-License-Identifier: MPL-2.0

import Foundation
import Synchronization

struct WallpaperTagManifest: Decodable, Sendable {
	let schemaVersion: Int
	let tags: [String: [String]]
}

/// Holds the current wallpaper tags: the bundled manifest as the offline baseline, plus the
/// repository's current manifest once the gallery downloads it, so tags for new wallpapers reach
/// players without a launcher release.
final class WallpaperTagStore: Sendable {
	static let shared = WallpaperTagStore(bundled: WallpaperTagCatalog.loadBundled())

	private let bundled: [String: [String]]
	private let storage: Mutex<[String: [String]]>

	init(bundled: [String: [String]]) {
		self.bundled = bundled
		storage = Mutex(bundled)
	}

	var tags: [String: [String]] { storage.withLock { $0 } }

	/// Adds a downloaded manifest's tags; its entries replace bundled entries with the same ID.
	func apply(_ downloaded: [String: [String]]) {
		let merged = bundled.merging(downloaded) { _, new in new }
		storage.withLock { $0 = merged }
	}

	/// Drops downloaded tags, for example after the gallery cache was cleared.
	func resetToBundled() {
		storage.withLock { $0 = bundled }
	}
}

enum WallpaperTagCatalog {
	static let supportedSchemaVersion = 1

	static var shared: [String: [String]] { WallpaperTagStore.shared.tags }

	static func tags(for wallpaperID: String) -> [String] {
		let tags = shared
		if let match = tags[wallpaperID] { return match }
		guard wallpaperID.hasPrefix("wp_") else { return [] }
		return tags["global-" + String(wallpaperID.dropFirst(3))] ?? []
	}

	static func decode(_ data: Data) throws -> [String: [String]] {
		let manifest = try JSONDecoder().decode(WallpaperTagManifest.self, from: data)
		guard manifest.schemaVersion == supportedSchemaVersion else {
			throw DecodingError.dataCorrupted(
				DecodingError.Context(
					codingPath: [],
					debugDescription: "Unsupported wallpaper tag schema \(manifest.schemaVersion)"
				)
			)
		}
		return manifest.tags
	}

	fileprivate static func loadBundled() -> [String: [String]] {
		// Packaged apps flatten copied resources into Bundle.main; SwiftPM uses its resource bundle.
		guard
			let url = Bundle.main.url(forResource: "WallpaperTags", withExtension: "json")
				?? AppResourceBundle.bundle.url(forResource: "WallpaperTags", withExtension: "json")
		else {
			NSLog("ArknightsClient could not find the bundled WallpaperTags.json.")
			return [:]
		}
		do {
			return try decode(Data(contentsOf: url))
		} catch {
			NSLog("ArknightsClient could not read WallpaperTags.json: \(error)")
			return [:]
		}
	}
}
