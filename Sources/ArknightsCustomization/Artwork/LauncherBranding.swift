// SPDX-License-Identifier: MPL-2.0

import AppKit
import ArknightsCore
import ArknightsInfrastructure
import Foundation

/// Downloads and disk-caches launcher artwork and the active region's official wordmark, so
/// unchanged assets across launches or branding refreshes don't refetch.
package actor ArtworkCache {
	private let loader: BoundedHTTPDataLoader
	private nonisolated let directory: URL
	private let clock: any Clock<Duration>
	private var activeImageRequestIDs: [GameRegion: UUID] = [:]

	package init(
		session: URLSession = .shared,
		directory: URL,
		clock: any Clock<Duration> = ContinuousClock()
	) {
		loader = BoundedHTTPDataLoader(
			session: session,
			maximumBufferedBytes: AppConstants.Network.maximumBufferedStreamBytes
		)
		self.directory = directory
		self.clock = clock
	}

	package nonisolated func cachedActiveImageData(for region: GameRegion) throws -> (String, Data)?
	{
		guard let cacheKey = try cachedActiveCacheKey(for: region) else { return nil }
		let data = try BoundedFileReader.readRegularFile(
			at: cachedImageURL(for: cacheKey),
			maximumBytes: AppConstants.Artwork.launcherMaximumBytes
		)
		return data.isEmpty ? nil : (cacheKey, data)
	}

	package nonisolated func cachedActiveCacheKey(for region: GameRegion) throws -> String? {
		let pointerURL = activeCacheKeyURL(for: region)
		guard FileManager.default.fileExists(atPath: pointerURL.path) else { return nil }
		let cacheKey = try String(contentsOf: pointerURL, encoding: .utf8)
		guard Self.safeCacheKey(cacheKey) == cacheKey else { return nil }
		return cacheKey
	}

	package nonisolated func cacheKey(for branding: LauncherBranding) -> String? {
		guard let sourceURL = branding.launcherBackgroundImage else { return nil }
		let rawKey = branding.launcherBackgroundImageCRC64 ?? sourceURL.lastPathComponent
		let cacheKey = Self.safeCacheKey(rawKey)
		return cacheKey.isEmpty ? nil : cacheKey
	}

	package nonisolated func cachedOfficialLogoData(for region: GameRegion) throws -> Data? {
		let cacheURL = officialLogoCacheURL(for: region)
		guard FileManager.default.fileExists(atPath: cacheURL.path) else { return nil }
		let data = try BoundedFileReader.readRegularFile(
			at: cacheURL,
			maximumBytes: AppConstants.Artwork.officialLogoMaximumBytes
		)
		return data.isEmpty ? nil : data
	}

	package func imageData(for branding: LauncherBranding, region: GameRegion) async throws -> Data?
	{
		let requestID = UUID()
		activeImageRequestIDs[region] = requestID
		guard let sourceURL = branding.launcherBackgroundImage else {
			try removeActiveCacheKey(for: region)
			return nil
		}
		guard let safeKey = cacheKey(for: branding) else { return nil }

		let fileManager = FileManager.default
		let cachedURL = cachedImageURL(for: safeKey)
		do {
			let data = try BoundedFileReader.readRegularFile(
				at: cachedURL,
				maximumBytes: AppConstants.Artwork.launcherMaximumBytes
			)
			if !data.isEmpty, NSImage(data: data) != nil {
				guard isCurrentImageRequest(requestID, region: region) else { return nil }
				try persistActiveCacheKey(safeKey, for: region)
				return data
			}
		} catch {
			// A missing or malformed cache is recovered by downloading the active
			// official asset below.
		}

		guard
			let data = try await downloadArtwork(
				from: sourceURL, region: region, requestID: requestID),
			isCurrentImageRequest(requestID, region: region)
		else { return nil }

		try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
		try pruneCache(incomingBytes: Int64(data.count), preserving: cachedURL)
		try data.write(to: cachedURL, options: .atomic)
		try persistActiveCacheKey(safeKey, for: region)
		return data
	}

	private func isCurrentImageRequest(_ requestID: UUID, region: GameRegion) -> Bool {
		activeImageRequestIDs[region] == requestID
	}

	package func officialLogoData(for region: GameRegion) async throws -> Data? {
		let cachedURL = officialLogoCacheURL(for: region)
		do {
			let data = try BoundedFileReader.readRegularFile(
				at: cachedURL,
				maximumBytes: AppConstants.Artwork.officialLogoMaximumBytes
			)
			if !data.isEmpty, NSImage(data: data) != nil {
				return data
			}
		} catch {
			// A missing cache is the normal first-launch path. A malformed cache is
			// treated the same way so a transient or interrupted prior response can
			// never pin the regional wordmark to the text fallback.
		}

		guard let sourceURL = Self.officialLogoURL(for: region) else { return nil }
		let data = try await downloadData(
			from: sourceURL,
			policy: HTTPFetchPolicy(
				maximumBytes: AppConstants.Artwork.officialLogoMaximumBytes,
				attemptsPerCandidate: AppConstants.Network.maxDownloadAttempts,
				backoffStep: AppConstants.Network.retryBackoffStep
			),
			region: region
		)

		try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
		try pruneCache(incomingBytes: Int64(data.count), preserving: cachedURL)
		try data.write(to: cachedURL, options: .atomic)
		return data
	}

	private var fetcher: CheckedHTTPFetcher { CheckedHTTPFetcher(loader: loader, clock: clock) }

	private func downloadData(
		from url: URL,
		policy: HTTPFetchPolicy,
		region: GameRegion
	) async throws -> Data {
		var request = URLRequest(url: url)
		request.cachePolicy = .reloadRevalidatingCacheData
		let result: HTTPFetchResult
		do {
			result = try await fetcher.fetch(
				[request],
				policy: policy,
				redirectValidator: Self.artworkRedirectValidator(for: region)
			)
		} catch HTTPFetchError.unexpectedStatus(let status, _)
			where !(500..<600).contains(status)
		{
			throw LauncherError.invalidResponse
		}
		guard !result.data.isEmpty else { throw LauncherError.invalidResponse }
		guard NSImage(data: result.data) != nil else { throw LauncherError.invalidResponse }
		return result.data
	}

	/// Makes one attempt per try and retries transient failures after doubling waits. A wait
	/// ends early when a newer request for the region has replaced this one.
	private func downloadArtwork(
		from url: URL,
		region: GameRegion,
		requestID: UUID
	) async throws -> Data? {
		var retries = 0
		while true {
			do {
				return try await downloadData(
					from: url,
					policy: HTTPFetchPolicy(
						maximumBytes: AppConstants.Artwork.launcherMaximumBytes
					),
					region: region
				)
			} catch let error where Self.isTransient(error) {
				guard retries < AppConstants.Artwork.transientRetryLimit else { throw error }
				retries += 1
				let delay = AppConstants.Artwork.transientRetryBaseDelay * (1 << (retries - 1))
				try await clock.sleep(for: delay, tolerance: delay / 10)
				guard isCurrentImageRequest(requestID, region: region) else { return nil }
			}
		}
	}

	/// Connectivity, timeout, and server failures can succeed on a later attempt. A rejected
	/// host or an invalid image cannot.
	private static func isTransient(_ error: any Error) -> Bool {
		if case HTTPFetchError.unexpectedStatus(let status, _) = error {
			return (500..<600).contains(status)
		}
		guard let urlError = error as? URLError else { return false }
		switch urlError.code {
		case .timedOut, .cannotConnectToHost, .networkConnectionLost, .notConnectedToInternet,
			.dnsLookupFailed:
			return true
		default:
			return false
		}
	}

	private nonisolated func officialLogoCacheURL(for region: GameRegion) -> URL {
		directory.appending(path: "official-arknights-logo-" + region.rawValue + ".png")
	}

	private nonisolated func pruneCache(incomingBytes: Int64, preserving target: URL) throws {
		try CacheDirectoryPruner.enforceLimit(
			at: directory,
			maximumBytes: AppConstants.Presets.artworkCacheMaximumBytes,
			incomingBytes: incomingBytes,
			preserving: target,
			pathExtensions: ["jpg", "png"]
		)
	}

	private nonisolated func cachedImageURL(for cacheKey: String) -> URL {
		directory.appending(path: "\(cacheKey).jpg")
	}

	private nonisolated func activeCacheKeyURL(for region: GameRegion) -> URL {
		directory.appending(path: "active-\(region.rawValue).txt")
	}

	private func persistActiveCacheKey(_ cacheKey: String, for region: GameRegion) throws {
		try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
		try cacheKey.write(
			to: activeCacheKeyURL(for: region),
			atomically: true,
			encoding: .utf8
		)
	}

	private func removeActiveCacheKey(for region: GameRegion) throws {
		let url = activeCacheKeyURL(for: region)
		guard FileManager.default.fileExists(atPath: url.path) else { return }
		try FileManager.default.removeItem(at: url)
	}

	private nonisolated static func safeCacheKey(_ value: String) -> String {
		String(
			value.prefix(256).filter {
				$0.isLetter || $0.isNumber || $0 == "-" || $0 == "_"
			}
		)
	}

	package nonisolated static func artworkRedirectValidator(
		for region: GameRegion
	) -> @Sendable (URL) -> Bool {
		let allowedHosts: Set<String> =
			switch region {
			case .global:
				[
					"webusstatic.yo-star.com",
					"www.arknights.global",
					"launcher-pkg-ark-en.yo-star.com",
					"launcher-pkg-ark-en-bk.yo-star.com",
				]
			case .japan:
				[
					"webusstatic.yo-star.com",
					"arknights.jp",
					"www.arknights.jp",
					"launcher-pkg-ark-jp.yo-star.com",
					"launcher-pkg-ark-jp-bk.yo-star.com",
				]
			case .korea:
				[
					"webusstatic.yo-star.com",
					"arknights.kr",
					"www.arknights.kr",
					"launcher-pkg-ark-kr.yo-star.com",
					"launcher-pkg-ark-kr-bk.yo-star.com",
				]
			case .taiwan:
				[
					"launcher.hg-cdn.com",
					"ak-tw.hg-cdn.com",
					"gl-utils-public.hg-cdn.com",
					"zh.wikifur.com",
				]
			case .china, .chinaBilibili:
				["zh.wikifur.com"]
			}

		return { url in
			guard url.scheme?.lowercased() == "https",
				url.user == nil,
				url.password == nil,
				url.port == nil,
				let host = url.host?.lowercased()
			else { return false }
			return allowedHosts.contains(host)
				|| ((region == .china || region == .chinaBilibili)
					&& host.hasSuffix(".hycdn.cn"))
		}
	}

	package nonisolated static func officialLogoURL(for region: GameRegion) -> URL? {
		switch region {
		case .global:
			URL(
				string:
					"https://webusstatic.yo-star.com/arknights-us/arknights-us-website/main/h5/assets/logo-4f95ced5.png"
			)!
		case .japan:
			URL(
				string:
					"https://webusstatic.yo-star.com/arknights-jp/arknights-jp-website/main/arknights-jp-website/assets/logo-0bd0cb04.png"
			)!
		case .korea:
			URL(
				string:
					"https://webusstatic.yo-star.com/arknights-kr/arknights-kr-website/main/arknights-kr-website/assets/logo-7510becf.png"
			)!
		case .taiwan, .china, .chinaBilibili:
			// No first-party logo exists, so these regions use the community wiki logo.
			URL(string: "https://zh.wikifur.com/w/images/b/b3/Arknights_CN_Logo.png")!
		}
	}
}
