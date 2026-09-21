// SPDX-License-Identifier: MPL-2.0

import Foundation

enum PresetCatalogSearch {
	private static let knownWallpaperTags = Set(
		WallpaperTagCatalog.shared.values.flatMap { $0 }.map(WallpaperSearch.normalized)
	)

	static func avatars(matching query: String, in avatars: [PresetAvatar]) async throws
		-> [PresetAvatar]
	{
		await Task.yield()
		try Task.checkCancellation()
		return try await ranked(avatars, matching: query) { $0.searchableValues }
	}

	static func wallpapers(
		matching query: String,
		category: WallpaperCategory? = nil,
		in wallpapers: [PresetWallpaper]
	)
		async throws -> [PresetWallpaper]
	{
		await Task.yield()
		try Task.checkCancellation()
		var directMatches: [PresetWallpaper] = []
		for wallpaper in wallpapers {
			try Task.checkCancellation()
			let prose = [wallpaper.displayTitle, wallpaper.author, wallpaper.description]
				.compactMap { $0 }
				.joined(separator: " ")
			if WallpaperSearch.matches(
				title: prose,
				tags: WallpaperTagCatalog.tags(for: wallpaper.id),
				category: wallpaper.category,
				query: query.trimmingCharacters(in: .whitespacesAndNewlines),
				selectedCategory: category,
				knownTags: knownWallpaperTags
			) {
				directMatches.append(wallpaper)
			}
		}
		let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
		guard trimmedQuery.count >= 3, !trimmedQuery.contains(where: \.isWhitespace) else {
			return directMatches
		}
		let directIDs = Set(directMatches.map(\.id))
		var candidates: [PresetWallpaper] = []
		for wallpaper in wallpapers {
			try Task.checkCancellation()
			if category == nil || wallpaper.category == category {
				candidates.append(wallpaper)
			}
		}
		let fuzzyMatches = try await ranked(
			candidates,
			matching: trimmedQuery
		) {
			[$0.displayTitle, $0.author, $0.description].compactMap { $0 }
				+ WallpaperTagCatalog.tags(for: $0.id)
		}.filter { !directIDs.contains($0.id) }
		return directMatches + fuzzyMatches
	}

	static func wallpaperSuggestions(
		matching query: String, in wallpapers: [PresetWallpaper]
	) async throws -> [String] {
		await Task.yield()
		try Task.checkCancellation()
		var searchableWallpapers: [(title: String, tags: [String])] = []
		searchableWallpapers.reserveCapacity(wallpapers.count)
		for wallpaper in wallpapers {
			try Task.checkCancellation()
			searchableWallpapers.append(
				(title: wallpaper.displayTitle, tags: WallpaperTagCatalog.tags(for: wallpaper.id))
			)
		}
		return try WallpaperSearch.suggestions(
			for: query,
			wallpapers: searchableWallpapers,
			knownTags: knownWallpaperTags,
			limit: AppConstants.Presets.gallerySuggestionLimit
		)
	}

	private static func ranked<Item>(
		_ items: [Item],
		matching query: String,
		values: (Item) -> [String]
	) async throws -> [Item] {
		let query = normalized(query.trimmingCharacters(in: .whitespacesAndNewlines))
		guard !query.isEmpty else { return items }
		var scored: [(score: Int, index: Int, item: Item)] = []
		scored.reserveCapacity(items.count)
		for (index, item) in items.enumerated() {
			try Task.checkCancellation()
			guard let score = try score(query: query, values: values(item)) else { continue }
			scored.append((score, index, item))
		}
		try Task.checkCancellation()
		return
			scored
			.sorted { lhs, rhs in
				if lhs.0 != rhs.0 { return lhs.0 < rhs.0 }
				return lhs.1 < rhs.1
			}
			.map(\.2)
	}

	private static func score(query: String, values: [String]) throws -> Int? {
		var scores: [Int] = []
		scores.reserveCapacity(values.count)
		for (index, value) in values.enumerated() {
			try Task.checkCancellation()
			let normalizedValue = normalized(value)
			guard !normalizedValue.isEmpty else { continue }
			if normalizedValue == query { return index }
			if normalizedValue.hasPrefix(query) { return 100 + index }
			if value.localizedStandardContains(query) { return 200 + index }
			guard let distance = try boundedDistance(query, to: normalizedValue) else { continue }
			scores.append(300 + distance * 10 + index)
		}
		return scores.min()
	}

	private static func normalized(_ value: String) -> String {
		value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
	}

	/// Allows one insertion, deletion, or substitution against a field or one of its windows.
	private static func boundedDistance(_ query: String, to value: String) throws -> Int? {
		let queryCharacters = Array(query)
		let valueCharacters = Array(value)
		guard queryCharacters.count >= 3 else { return nil }
		let windowLengths = [
			queryCharacters.count - 1, queryCharacters.count, queryCharacters.count + 1,
		]
		var best: Int?
		for length in windowLengths where length > 0 && length <= valueCharacters.count {
			for start in 0...(valueCharacters.count - length) {
				try Task.checkCancellation()
				let window = Array(valueCharacters[start..<(start + length)])
				guard let distance = try levenshtein(queryCharacters, window, limit: 1) else {
					continue
				}
				best = min(best ?? distance, distance)
				if best == 0 { return 0 }
			}
		}
		return best
	}

	private static func levenshtein(
		_ lhs: [Character], _ rhs: [Character], limit: Int
	) throws -> Int? {
		var previous = Array(0...rhs.count)
		for (row, lhsCharacter) in lhs.enumerated() {
			try Task.checkCancellation()
			var current = [row + 1]
			for (column, rhsCharacter) in rhs.enumerated() {
				current.append(
					lhsCharacter == rhsCharacter
						? previous[column]
						: min(previous[column], current[column], previous[column + 1]) + 1
				)
			}
			if current.min() ?? limit + 1 > limit { return nil }
			previous = current
		}
		let distance = previous.last ?? limit + 1
		return distance <= limit ? distance : nil
	}
}
