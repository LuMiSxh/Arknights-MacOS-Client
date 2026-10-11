// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameInstallation
import ArknightsInfrastructure
import Foundation
internal import Sparkle

nonisolated struct LauncherAnnouncementFeed: Decodable, Sendable {
	let schemaVersion: Int
	let announcements: [LauncherAnnouncement]
}

/// A repository-hosted, one-time message; `isEligible` is the single gate for whether it's
/// shown, checking the seen-IDs set, an active date window, version bounds, and field limits
/// together so a malformed or already-dismissed entry can't surface.
nonisolated struct LauncherAnnouncement: Decodable, Sendable, Equatable, Identifiable {
	let id: String
	let enabled: Bool
	let title: String
	let body: String
	let actionTitle: String?
	let actionURL: URL?
	let minimumVersion: String?
	let maximumVersion: String?
	let startsAt: Date?
	let endsAt: Date?

	func isEligible(currentVersion: String, now: Date, seenIDs: Set<String>) -> Bool {
		guard enabled, !seenIDs.contains(id) else { return false }
		guard !id.isEmpty, id.count <= 80, title.count <= 120, body.count <= 4_000 else {
			return false
		}
		if let startsAt, now < startsAt { return false }
		if let endsAt, now >= endsAt { return false }
		if let minimumVersion {
			guard let order = Self.compare(currentVersion, minimumVersion),
				order != .orderedAscending
			else { return false }
		}
		if let maximumVersion {
			guard let order = Self.compare(currentVersion, maximumVersion),
				order != .orderedDescending
			else { return false }
		}
		guard Self.normalized(currentVersion) != nil else { return false }
		if let actionURL, actionURL.scheme?.lowercased() != "https" { return false }
		return true
	}

	/// Orders two release tags with Sparkle's comparator. Sparkle ignores a "-prerelease" suffix,
	/// so the core versions compare first, then a prerelease sorts before its release. A leading
	/// "v" and "+build" metadata are ignored. Returns nil for a non-version.
	static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult? {
		guard let lhs = normalized(lhs), let rhs = normalized(rhs) else { return nil }
		let comparator = SUStandardVersionComparator()
		let left = lhs.split(separator: "-", maxSplits: 1).map(String.init)
		let right = rhs.split(separator: "-", maxSplits: 1).map(String.init)
		let core = comparator.compareVersion(left[0], toVersion: right[0])
		guard core == .orderedSame else { return core }
		switch (left.dropFirst().first, right.dropFirst().first) {
		case (nil, nil): return .orderedSame
		case (nil, _): return .orderedDescending
		case (_, nil): return .orderedAscending
		case (let leftPrerelease?, let rightPrerelease?):
			return comparator.compareVersion(leftPrerelease, toVersion: rightPrerelease)
		}
	}

	private static func normalized(_ version: String) -> String? {
		var trimmed = Substring(version.trimmingCharacters(in: .whitespacesAndNewlines))
		if trimmed.first?.lowercased() == "v" { trimmed = trimmed.dropFirst() }
		let core = trimmed.prefix { $0 != "+" }
		guard core.first?.isASCII == true, core.first?.isNumber == true else { return nil }
		return String(core)
	}
}

/// Fetches this repository's `announcements.json` for one-time project messages, separate
/// from Yostar's own in-game notices.
nonisolated struct LauncherAnnouncementService: Sendable {
	private let loader: BoundedHTTPDataLoader

	init(session: URLSession = .shared) {
		loader = BoundedHTTPDataLoader(
			session: session,
			maximumBufferedBytes: AppConstants.Network.maximumBufferedStreamBytes
		)
	}

	func announcements(from endpoint: URL) async throws -> [LauncherAnnouncement] {
		var request = URLRequest(url: endpoint)
		request.cachePolicy = .reloadRevalidatingCacheData
		request.setValue("application/vnd.github.raw+json", forHTTPHeaderField: "Accept")
		request.setValue("ArknightsClient", forHTTPHeaderField: "User-Agent")
		let data: Data
		let response: HTTPURLResponse
		do {
			(data, response) = try await loader.data(
				for: request,
				maximumBytes: AppConstants.Network.announcementFeedMaximumBytes
			)
		} catch is CancellationError {
			throw CancellationError()
		} catch let error as HTTPTransportError {
			if Task.isCancelled { throw CancellationError() }
			throw Self.mapTransportError(error)
		}
		if response.statusCode == 404 { return [] }
		guard response.statusCode == 200 else {
			throw LauncherError.invalidResponse
		}

		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .iso8601
		let feed = try decoder.decode(LauncherAnnouncementFeed.self, from: data)
		guard feed.schemaVersion == 1, feed.announcements.count <= 20 else {
			throw LauncherError.invalidResponse
		}
		return feed.announcements
	}

	private static func mapTransportError(_ error: HTTPTransportError) -> any Error {
		GameInstaller.launcherError(for: error)
	}
}
