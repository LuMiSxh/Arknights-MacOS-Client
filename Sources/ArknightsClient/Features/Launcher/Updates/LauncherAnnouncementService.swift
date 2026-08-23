// SPDX-License-Identifier: MPL-2.0

import Foundation

struct LauncherAnnouncementFeed: Decodable, Sendable {
	let schemaVersion: Int
	let announcements: [LauncherAnnouncement]
}

/// A repository-hosted, one-time message; `isEligible` is the single gate for whether it's
/// shown, checking the seen-IDs set, an active date window, version bounds, and field limits
/// together so a malformed or already-dismissed entry can't surface.
struct LauncherAnnouncement: Decodable, Sendable, Equatable, Identifiable {
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
		guard let current = SemanticVersion(currentVersion) else { return false }
		if let minimumVersion {
			guard let minimum = SemanticVersion(minimumVersion), current >= minimum else {
				return false
			}
		}
		if let maximumVersion {
			guard let maximum = SemanticVersion(maximumVersion), current <= maximum else {
				return false
			}
		}
		if let actionURL, actionURL.scheme?.lowercased() != "https" { return false }
		return true
	}
}

/// Fetches this repository's `announcements.json` for one-time project messages, separate
/// from Yostar's own in-game notices.
struct LauncherAnnouncementService: Sendable {
	private let loader: BoundedHTTPDataLoader

	init(session: URLSession = .shared) {
		loader = BoundedHTTPDataLoader(session: session)
	}

	func announcements(from endpoint: URL) async throws -> [LauncherAnnouncement] {
		var request = URLRequest(url: endpoint)
		request.cachePolicy = .reloadRevalidatingCacheData
		request.setValue("application/vnd.github.raw+json", forHTTPHeaderField: "Accept")
		request.setValue("ArknightsClient", forHTTPHeaderField: "User-Agent")
		let (data, response) = try await loader.data(
			for: request,
			maximumBytes: AppConstants.Network.announcementFeedMaximumBytes
		)
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
}
