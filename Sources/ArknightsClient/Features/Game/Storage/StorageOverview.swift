// SPDX-License-Identifier: MPL-2.0

import Foundation

/// A user-visible storage bucket. The runtime is global; prefix storage is shared by publisher family.
enum StorageCategory: Hashable, Identifiable, Sendable {
	case game(GameRegion)
	case winePrefix
	case compatibilityRuntime
	case dxmtCache
	case browserCache
	case galleryCache
	case logs

	var id: String {
		switch self {
		case .game(let region): "game." + region.rawValue
		case .winePrefix: "wine-prefix"
		case .compatibilityRuntime: "compatibility-runtime"
		case .dxmtCache: "dxmt-cache"
		case .browserCache: "browser-cache"
		case .galleryCache: "gallery-cache"
		case .logs: "logs"
		}
	}
}

/// One or more paths owned by a storage bucket. Browser caches have one directory per Wine user.
struct StorageLocation: Equatable, Sendable {
	let category: StorageCategory
	let urls: [URL]
}

struct StorageUsage: Equatable, Identifiable, Sendable {
	let location: StorageLocation
	let byteCount: Int64?
	let exists: Bool

	var id: String { location.category.id }
}

struct StorageOverviewContext: Equatable, Sendable {
	let region: GameRegion
	let canaryFeaturesEnabled: Bool
	let persistedInstallDirectories: [GameRegion: URL]
}

enum StorageOverviewResolver {
	@MainActor
	static func context(
		preferences: LauncherPreferencesStore,
		region: GameRegion
	) -> StorageOverviewContext {
		StorageOverviewContext(
			region: region,
			canaryFeaturesEnabled: preferences.canaryFeaturesEnabled(),
			persistedInstallDirectories: preferences.persistedInstallDirectories()
		)
	}

	@MainActor
	static func locations(
		paths: AppPaths,
		preferences: LauncherPreferencesStore,
		region: GameRegion = .global,
		fileManager: FileManager = .default
	) -> [StorageLocation] {
		locations(
			paths: paths,
			context: context(preferences: preferences, region: region),
			fileManager: fileManager
		)
	}

	static func locations(
		paths: AppPaths,
		context: StorageOverviewContext,
		fileManager: FileManager = .default
	) -> [StorageLocation] {
		let games = GameRegion.selectableCases(
			canaryEnabled: context.canaryFeaturesEnabled
		).map { region in
			StorageLocation(
				category: .game(region),
				urls: [
					context.persistedInstallDirectories[region] ?? paths.gameInstall(for: region)
				]
			)
		}
		let browserCaches = paths.browserCacheDirectories(
			for: context.region,
			fileManager: fileManager
		)

		return games + [
			StorageLocation(category: .winePrefix, urls: [paths.winePrefix(for: context.region)]),
			StorageLocation(
				category: .compatibilityRuntime,
				urls: paths.bundledRuntimeDirectory.map { [$0] } ?? []
			),
			StorageLocation(
				category: .dxmtCache,
				urls: [paths.dxmtCache(for: context.region)]
			),
			StorageLocation(category: .browserCache, urls: browserCaches),
			StorageLocation(category: .galleryCache, urls: [paths.presetGalleryCache]),
			StorageLocation(category: .logs, urls: [paths.logsDirectory]),
		]
	}

	static func placeholderLocations(context: StorageOverviewContext) -> [StorageLocation] {
		let games = GameRegion.selectableCases(canaryEnabled: context.canaryFeaturesEnabled).map {
			StorageLocation(category: .game($0), urls: [])
		}
		return games + [
			StorageLocation(category: .winePrefix, urls: []),
			StorageLocation(category: .compatibilityRuntime, urls: []),
			StorageLocation(category: .dxmtCache, urls: []),
			StorageLocation(category: .browserCache, urls: []),
			StorageLocation(category: .galleryCache, urls: []),
			StorageLocation(category: .logs, urls: []),
		]
	}
}

enum StorageSizeCalculator {
	static func measure(
		_ locations: [StorageLocation],
		fileManager: FileManager = .default
	) throws -> [StorageUsage] {
		try locations.map { location in
			try Task.checkCancellation()
			guard !location.urls.isEmpty else {
				return StorageUsage(location: location, byteCount: nil, exists: false)
			}

			let existingURLs = location.urls.filter {
				fileManager.fileExists(atPath: $0.path)
			}
			guard !existingURLs.isEmpty else {
				return StorageUsage(location: location, byteCount: nil, exists: false)
			}

			var byteCount: Int64 = 0
			for url in existingURLs {
				try Task.checkCancellation()
				byteCount += try directorySize(at: url, fileManager: fileManager)
			}
			return StorageUsage(location: location, byteCount: byteCount, exists: true)
		}
	}

	private static func directorySize(
		at url: URL,
		fileManager: FileManager
	) throws -> Int64 {
		guard !isSymbolicLink(url, fileManager: fileManager) else { return 0 }
		guard
			let enumerator = fileManager.enumerator(
				at: url,
				includingPropertiesForKeys: [.fileSizeKey, .isSymbolicLinkKey]
			)
		else { return 0 }

		var total: Int64 = 0
		for case let fileURL as URL in enumerator {
			try Task.checkCancellation()
			if isSymbolicLink(fileURL, fileManager: fileManager) {
				enumerator.skipDescendants()
				continue
			}
			let values = try fileURL.resourceValues(forKeys: [.fileSizeKey])
			total += Int64(values.fileSize ?? 0)
		}
		return total
	}

	private static func isSymbolicLink(_ url: URL, fileManager: FileManager) -> Bool {
		guard fileManager.fileExists(atPath: url.path) else { return false }
		return (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true
	}
}
