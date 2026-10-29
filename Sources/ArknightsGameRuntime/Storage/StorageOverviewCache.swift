// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsInfrastructure
import Foundation

/// Persists the last Storage measurements so Settings can show numbers before the next
/// measurement finishes. The file only seeds the page; every page open still re-measures.
struct StorageOverviewCacheStore: Sendable {
	let fileURL: URL
	let log: LauncherLog
	private let files = JSONFileStore(maximumBytes: AppConstants.Storage.overviewCacheMaximumBytes)

	init(fileURL: URL, log: LauncherLog) {
		self.fileURL = fileURL
		self.log = log
	}

	/// Returns no entries when the file is missing, unreadable, or from another format version.
	/// The next save replaces such a file.
	func loadSynchronously() -> [StorageOverviewCacheEntry] {
		do {
			guard let file = try files.read(StorageOverviewCacheFile.self, at: fileURL) else {
				return []
			}
			guard file.formatVersion == AppConstants.Storage.overviewCacheFormatVersion else {
				log.error(
					"Ignored storage overview cache with format version \(file.formatVersion)"
				)
				return []
			}
			return file.entries
		} catch {
			log.error("Ignored unreadable storage overview cache: \(error.localizedDescription)")
			return []
		}
	}

	@concurrent
	func save(_ entries: [StorageOverviewCacheEntry]) async {
		let file = StorageOverviewCacheFile(
			formatVersion: AppConstants.Storage.overviewCacheFormatVersion,
			entries: entries
		)
		log.attempt("Could not save storage overview cache") {
			try files.write(file, to: fileURL, createParentDirectory: true)
		}
	}
}

/// Versioned file body. Entries are ordered most recent first.
struct StorageOverviewCacheFile: Codable {
	let formatVersion: Int
	let entries: [StorageOverviewCacheEntry]
}

struct StorageOverviewCacheEntry: Codable, Equatable {
	let key: StorageOverviewCacheKey
	let usages: [CachedStorageUsage]
}

/// The context inputs that change what Storage measures. Install directories are stored as
/// paths so that the key stays Codable.
struct StorageOverviewCacheKey: Codable, Equatable {
	let region: GameRegion
	let canaryFeaturesEnabled: Bool
	let taiwanClientEnabled: Bool
	let installDirectories: [GameRegion: String]

	init(context: StorageOverviewContext) {
		region = context.region
		canaryFeaturesEnabled = context.regionAccess.canaryFeaturesEnabled
		taiwanClientEnabled = context.regionAccess.taiwanClientEnabled
		installDirectories = context.persistedInstallDirectories.mapValues(\.path)
	}
}

/// One category's measured size. Categories are keyed by `StorageCategory.id`, so the cache
/// stores no URLs.
struct CachedStorageUsage: Codable, Equatable {
	let categoryID: String
	let byteCount: Int64?
	let exists: Bool

	init(_ usage: StorageUsage) {
		categoryID = usage.id
		byteCount = usage.byteCount
		exists = usage.exists
	}
}
