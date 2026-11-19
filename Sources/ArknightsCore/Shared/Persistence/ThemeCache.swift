// SPDX-License-Identifier: MPL-2.0

import ArknightsInfrastructure
import Foundation
import Synchronization

/// The derived theme values stored in one JSON document at `AppPaths.themeCache`.
/// A missing file, another schema, or unreadable bytes all mean an empty cache.
struct ThemeCacheDocument: Codable, Sendable, Equatable {
	struct Accent: Codable, Sendable, Equatable {
		let key: String
		let hue: Double
		let saturation: Double
		let brightness: Double
	}

	struct Luminance: Codable, Sendable, Equatable {
		let identity: String
		let score: Double
	}

	var schemaVersion = AppConstants.Theme.themeCacheSchemaVersion
	/// Oldest first, so the first entry is evicted first.
	var accents: [Accent] = []
	/// Oldest first.
	var luminance: [Luminance] = []
}

struct ThemeCacheFile: Sendable {
	/// Fits both entry caps at their longest possible keys.
	private static let maximumBytes = 64 * 1_024

	let url: URL
	let log: LauncherLog?

	func read() -> ThemeCacheDocument {
		do {
			guard
				let document = try JSONFileStore(maximumBytes: Self.maximumBytes).read(
					ThemeCacheDocument.self, at: url),
				document.schemaVersion == AppConstants.Theme.themeCacheSchemaVersion
			else { return ThemeCacheDocument() }
			return document
		} catch {
			log?.error(
				"Ignored the theme cache at \(url.path): \(launcherDiagnosticDescription(for: error))"
			)
			return ThemeCacheDocument()
		}
	}

	func write(_ document: ThemeCacheDocument) throws {
		try JSONFileStore(maximumBytes: Self.maximumBytes).write(
			document, to: url, createParentDirectory: true)
	}
}

/// The in-memory copy of the theme cache, shared by every caller of one `LauncherPreferencesStore`.
/// The file is read once at creation; later reads and mutations stay in memory under `state`.
final class ThemeCacheStore: Sendable {
	private struct State: Sendable {
		var document: ThemeCacheDocument
		var tick: UInt64
		var generation: UInt64 = 0
		/// Recency uses a monotonic counter so a clock change can never reorder the entries.
		var accentRecency: [String: UInt64]
		var luminanceRecency: [String: UInt64]
	}

	private let file: ThemeCacheFile
	private let state: Mutex<State>
	/// Serializes writes so an older document can never replace a newer one.
	private let persistedGeneration = Mutex<UInt64>(0)

	init(file: ThemeCacheFile) {
		self.file = file
		let document = file.read()
		var accentRecency: [String: UInt64] = [:]
		for (index, accent) in document.accents.enumerated() {
			accentRecency[accent.key] = UInt64(index + 1)
		}
		var luminanceRecency: [String: UInt64] = [:]
		for (index, record) in document.luminance.enumerated() {
			luminanceRecency[record.identity] = UInt64(index + 1)
		}
		state = Mutex(
			State(
				document: document,
				tick: UInt64(max(document.accents.count, document.luminance.count)),
				accentRecency: accentRecency,
				luminanceRecency: luminanceRecency
			))
	}

	func accent(for key: String) -> ThemeCacheDocument.Accent? {
		state.withLock { state in
			guard let accent = state.document.accents.first(where: { $0.key == key })
			else { return nil }
			state.tick += 1
			state.accentRecency[key] = state.tick
			return accent
		}
	}

	func setAccent(_ accent: ThemeCacheDocument.Accent?, for key: String) {
		let write = state.withLock { state -> (document: ThemeCacheDocument, generation: UInt64)? in
			guard accent != nil || state.document.accents.contains(where: { $0.key == key })
			else { return nil }
			state.document.accents.removeAll { $0.key == key }
			state.accentRecency[key] = nil
			if let accent {
				state.tick += 1
				state.document.accents.append(accent)
				state.accentRecency[key] = state.tick
				Self.evictAccents(&state, limit: AppConstants.Theme.themeAccentCacheLimit)
			}
			state.generation += 1
			return (state.document, state.generation)
		}
		if let write { persist(write.document, generation: write.generation) }
	}

	func luminance(for identity: String) -> Double? {
		state.withLock { state in
			guard let record = state.document.luminance.first(where: { $0.identity == identity })
			else { return nil }
			state.tick += 1
			state.luminanceRecency[identity] = state.tick
			return record.score
		}
	}

	func setLuminance(_ score: Double, for identity: String, limit: Int) {
		let write = state.withLock { state -> (document: ThemeCacheDocument, generation: UInt64) in
			state.document.luminance.removeAll { $0.identity == identity }
			state.tick += 1
			state.document.luminance.append(
				ThemeCacheDocument.Luminance(identity: identity, score: score))
			state.luminanceRecency[identity] = state.tick
			Self.evictLuminance(&state, limit: limit)
			state.generation += 1
			return (state.document, state.generation)
		}
		persist(write.document, generation: write.generation)
	}

	private static func evictAccents(_ state: inout State, limit: Int) {
		guard state.document.accents.count > limit else { return }
		let evicted = leastRecentlyUsed(
			state.document.accents.map { ($0.key, state.accentRecency[$0.key] ?? 0) },
			excess: state.document.accents.count - limit
		)
		state.document.accents.removeAll { evicted.contains($0.key) }
		for key in evicted { state.accentRecency[key] = nil }
	}

	private static func evictLuminance(_ state: inout State, limit: Int) {
		guard state.document.luminance.count > limit else { return }
		let ranks = state.document.luminance.map {
			($0.identity, state.luminanceRecency[$0.identity] ?? 0)
		}
		let evicted = leastRecentlyUsed(
			ranks, excess: state.document.luminance.count - limit)
		state.document.luminance.removeAll { evicted.contains($0.identity) }
		for identity in evicted { state.luminanceRecency[identity] = nil }
	}

	private static func leastRecentlyUsed(
		_ entries: [(key: String, rank: UInt64)],
		excess: Int
	) -> Set<String> {
		Set(entries.sorted { $0.rank < $1.rank }.prefix(excess).map(\.key))
	}

	// Writers serialize here, so a slower, older document never replaces a newer one. Reads keep
	// using `state` while the file is encoded and replaced.
	private func persist(_ document: ThemeCacheDocument, generation: UInt64) {
		persistedGeneration.withLock { lastPersisted in
			guard generation > lastPersisted else { return }
			do {
				try file.write(document)
				lastPersisted = generation
			} catch {
				file.log?.error(
					"Failed to write the theme cache at \(file.url.path): "
						+ launcherDiagnosticDescription(for: error)
				)
			}
		}
	}
}
