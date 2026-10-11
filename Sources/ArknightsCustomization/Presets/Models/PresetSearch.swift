// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation

/// Search and ranking for the preset gallery: wallpaper term matching, autocomplete, fuzzy
/// catalog ranking, and the gallery result pipeline.
enum PresetSearch {
	/// Whether `wallpaper` should be shown for the given search text and type filter.
	///
	/// `query` is treated as one or more space-separated terms that must ALL be found
	/// somewhere in the title or tags — so "twitter angelina" finds wallpapers that mention
	/// both, rather than requiring that exact combined phrase to appear as one substring
	/// (which essentially never happens once a query has more than one meaningful word).
	///
	/// The one exception is when the *entire* query is already the complete text of a known
	/// tag — e.g. "w" (a complete operator codename) or "kristen wright" typed or selected in
	/// full — in which case it matches only that exact tag, not every tag that merely starts
	/// with it (wang, warfarin, weedy, …) or splitting a legitimate multi-word tag into terms
	/// that individually fail to prefix-match past the first word.
	///
	/// - Parameter knownTags: every curated tag value, already passed through `normalized(_:)`.
	static func matches(
		title: String,
		tags: [String],
		category: WallpaperCategory,
		query: String,
		selectedCategory: WallpaperCategory?,
		knownTags: Set<String>
	) -> Bool {
		guard selectedCategory == nil || category == selectedCategory else { return false }
		guard !query.isEmpty else { return true }
		if title.localizedStandardContains(query) { return true }

		let normalizedQuery = normalized(query)
		if knownTags.contains(normalizedQuery) {
			return tags.contains { normalized($0) == normalizedQuery }
		}

		let terms = query.split(whereSeparator: \.isWhitespace).map(String.init)
		guard !terms.isEmpty else { return false }
		return terms.allSatisfy { matchesTerm($0, title: title, tags: tags, knownTags: knownTags) }
	}

	private static func matchesTerm(
		_ term: String, title: String, tags: [String], knownTags: Set<String>
	) -> Bool {
		if title.localizedStandardContains(term) { return true }

		let normalizedTerm = normalized(term)
		let termIsCompleteTag = knownTags.contains(normalizedTerm)
		return tags.contains { tag in
			let normalizedTag = normalized(tag)
			if termIsCompleteTag {
				return normalizedTag == normalizedTerm
			}
			return normalizedTag.hasPrefix(normalizedTerm)
		}
	}

	/// Autocomplete chips for the search box: matching tags first, then individual words from
	/// titles (not whole titles), deduplicated and capped at `limit`. Within each group, an
	/// exact match ranks first — otherwise a short tag can get crowded out of the capped list
	/// by longer candidates that merely contain it.
	///
	/// Candidates are matched by prefix, not substring — typing "w" suggests words that
	/// *start* with "w" (w, warfarin, Windflit, …), not any word with a "w" anywhere in it
	/// (Twitter, answer, …), which is how autocomplete conventionally behaves.
	///
	/// Only the last space-separated word of `query` drives matching, since earlier words are
	/// already-completed terms (per `matches(...)`) rather than something still being typed —
	/// e.g. for "twitter ang", candidates are matched against "ang", not the combined phrase.
	/// Candidates are additionally scoped to wallpapers that already satisfy every earlier
	/// term: otherwise a suggestion can look valid on its own (some tag/word starting with
	/// "ex" genuinely exists) while combining with what's already typed to match nothing,
	/// because that particular candidate never co-occurs with "twitter" on any wallpaper.
	/// Use `applyingSuggestion(_:to:)` to splice a chosen suggestion back in, preserving those
	/// earlier terms.
	static func suggestions(
		for query: String,
		wallpapers: [(title: String, tags: [String])],
		knownTags: Set<String>,
		limit: Int = 8
	) throws -> [String] {
		try Task.checkCancellation()
		guard query.last?.isWhitespace != true else { return [] }
		let terms = query.split(whereSeparator: \.isWhitespace).map(String.init)
		guard let lastTerm = terms.last, !lastTerm.isEmpty else { return [] }
		let earlierTerms = terms.dropLast()

		let candidates: [(title: String, tags: [String])]
		if earlierTerms.isEmpty {
			candidates = wallpapers
		} else {
			var scoped: [(title: String, tags: [String])] = []
			for wallpaper in wallpapers {
				try Task.checkCancellation()
				if earlierTerms.allSatisfy({
					matchesTerm(
						$0, title: wallpaper.title, tags: wallpaper.tags, knownTags: knownTags)
				}) {
					scoped.append(wallpaper)
				}
			}
			candidates = scoped
		}

		let normalizedQuery = normalized(lastTerm)
		func matchesCandidate(_ candidate: String) -> Bool {
			!candidate.isEmpty && normalized(candidate).hasPrefix(normalizedQuery)
		}
		func rank(_ candidate: String) -> Int {
			normalized(candidate) == normalizedQuery ? 0 : candidate.count
		}

		var seen = Set<String>()
		var tagSuggestions: [String] = []
		var titleWordSuggestions: [String] = []

		for wallpaper in candidates {
			try Task.checkCancellation()
			for tag in wallpaper.tags
			where matchesCandidate(tag) && seen.insert(normalized(tag)).inserted {
				tagSuggestions.append(tag)
			}
		}
		for wallpaper in candidates {
			try Task.checkCancellation()
			for word in wallpaper.title.components(separatedBy: titleWordSeparators)
			where matchesCandidate(word) && seen.insert(normalized(word)).inserted {
				titleWordSuggestions.append(word)
			}
		}
		tagSuggestions.sort { rank($0) < rank($1) }
		titleWordSuggestions.sort { rank($0) < rank($1) }

		return Array((tagSuggestions + titleWordSuggestions).prefix(limit))
	}

	/// Replaces the last space-separated term of `query` with `suggestion`, preserving any
	/// earlier already-typed terms — so picking a suggestion for "ang" while the box reads
	/// "twitter ang" produces "twitter angelina ", not just "angelina". A trailing space is
	/// always appended so the next term can be typed immediately, without an extra keystroke.
	static func applyingSuggestion(_ suggestion: String, to query: String) -> String {
		var terms = query.split(whereSeparator: \.isWhitespace).map(String.init)
		guard !terms.isEmpty else { return suggestion + " " }
		terms[terms.count - 1] = suggestion
		return terms.joined(separator: " ") + " "
	}

	/// Prefers the longest match so multi-word tags become one filter.
	static func trailingKnownTag(
		in query: String, canonicalTagsByNormalizedForm: [String: String]
	) -> (tag: String, remainingQuery: String)? {
		let terms = query.split(whereSeparator: \.isWhitespace).map(String.init)
		guard !terms.isEmpty else { return nil }

		for wordCount in stride(from: terms.count, through: 1, by: -1) {
			let phrase = terms.suffix(wordCount).joined(separator: " ")
			guard let canonical = canonicalTagsByNormalizedForm[normalized(phrase)] else {
				continue
			}
			let remainder = terms.dropLast(wordCount)
			let remainingQuery = remainder.isEmpty ? "" : remainder.joined(separator: " ") + " "
			return (canonical, remainingQuery)
		}
		return nil
	}

	static func tagsContain(_ tags: [String], exactly tag: String) -> Bool {
		let normalizedTag = normalized(tag)
		return tags.contains { normalized($0) == normalizedTag }
	}

	/// Case- and diacritic-folded form of `value`, used for every comparison in this type.
	///
	/// Foundation's `.diacriticInsensitive` string options don't fold every accented letter —
	/// notably Polish "ł" and the ligature "æ" aren't decomposable combining-mark sequences, so
	/// they pass through unchanged (verified directly; see the operator tags "młynar", "væla",
	/// and "ægir"). Those are folded explicitly before handing off to Foundation for the rest.
	static func normalized(_ value: String) -> String {
		value
			.replacingOccurrences(of: "ł", with: "l")
			.replacingOccurrences(of: "Ł", with: "L")
			.replacingOccurrences(of: "æ", with: "ae")
			.replacingOccurrences(of: "Æ", with: "AE")
			.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
	}

	private static let titleWordSeparators = CharacterSet.whitespaces.union(
		.punctuationCharacters)

	private static var knownWallpaperTags: Set<String> {
		Set(WallpaperTagCatalog.shared.values.flatMap { $0 }.map(PresetSearch.normalized))
	}

	static func avatars(
		matching query: String, in avatars: [PresetAvatar]
	) async throws
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
			if PresetSearch.matches(
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
		return try PresetSearch.suggestions(
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
		let query = rankingFolded(query.trimmingCharacters(in: .whitespacesAndNewlines))
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
			let normalizedValue = rankingFolded(value)
			guard !normalizedValue.isEmpty else { continue }
			if normalizedValue == query { return index }
			if normalizedValue.hasPrefix(query) { return 100 + index }
			if value.localizedStandardContains(query) { return 200 + index }
			guard let distance = try boundedDistance(query, to: normalizedValue) else { continue }
			scores.append(300 + distance * 10 + index)
		}
		return scores.min()
	}

	private static func rankingFolded(_ value: String) -> String {
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

	static func shouldPublishResults(
		request: PresetGallerySearchQuery,
		currentQuery: PresetGallerySearchQuery,
		isCancelled: Bool
	) -> Bool {
		!isCancelled && request.catalogReady && request == currentQuery
	}

	static func results(
		for destination: PresetGalleryDestination,
		searchText: String,
		committedTags: [String],
		selectedCategory: WallpaperCategory?,
		avatars avatarCatalog: [PresetAvatar],
		wallpapers wallpaperCatalog: [PresetWallpaper]
	) async throws -> PresetGallerySearchResults {
		await Task.yield()
		try Task.checkCancellation()
		switch destination {
		case .artwork:
			let matches = try await wallpapers(
				matching: searchText,
				committedTags: committedTags,
				category: nil,
				in: wallpaperCatalog
			)
			let filteredWallpapers: [PresetWallpaper]
			if let selectedCategory {
				var filtered: [PresetWallpaper] = []
				for wallpaper in matches {
					try Task.checkCancellation()
					if wallpaper.category == selectedCategory { filtered.append(wallpaper) }
				}
				filteredWallpapers = filtered
			} else {
				filteredWallpapers = matches
			}

			return PresetGallerySearchResults(
				filteredAvatars: [],
				filteredWallpapers: filteredWallpapers,
				wallpaperCategoryCounts: try categoryCounts(in: matches),
				wallpaperTerms: try await suggestions(
					matching: searchText,
					committedTags: committedTags,
					category: selectedCategory,
					in: wallpaperCatalog
				),
				operatorCounts: try operatorCounts(
					among: filteredWallpapers, avatars: avatarCatalog)
			)
		case .operatorIcons:
			return PresetGallerySearchResults(
				filteredAvatars: try await PresetSearch.avatars(
					matching: searchText, in: avatarCatalog
				),
				filteredWallpapers: [],
				wallpaperCategoryCounts: [:],
				wallpaperTerms: [],
				operatorCounts: []
			)
		}
	}

	static func wallpapers(
		matching searchText: String,
		committedTags: [String],
		category: WallpaperCategory?,
		in wallpaperCatalog: [PresetWallpaper]
	) async throws -> [PresetWallpaper] {
		try await PresetSearch.wallpapers(
			matching: searchText,
			category: category,
			in: try matchingTags(committedTags, in: wallpaperCatalog)
		)
	}

	static func suggestions(
		matching searchText: String,
		committedTags: [String],
		category: WallpaperCategory?,
		in wallpaperCatalog: [PresetWallpaper]
	) async throws -> [String] {
		let tagged = try matchingTags(committedTags, in: wallpaperCatalog)
		var candidates: [PresetWallpaper] = []
		for wallpaper in tagged {
			try Task.checkCancellation()
			if category == nil || wallpaper.category == category {
				candidates.append(wallpaper)
			}
		}
		let committed = Set(committedTags.map(PresetSearch.normalized))
		let suggestions = try await PresetSearch.wallpaperSuggestions(
			matching: searchText,
			in: candidates
		)
		return suggestions.filter { !committed.contains(PresetSearch.normalized($0)) }
	}

	private static func matchingTags(
		_ committedTags: [String], in wallpapers: [PresetWallpaper]
	) throws -> [PresetWallpaper] {
		var matches: [PresetWallpaper] = []
		for wallpaper in wallpapers {
			try Task.checkCancellation()
			if committedTags.allSatisfy({
				PresetSearch.tagsContain(
					WallpaperTagCatalog.tags(for: wallpaper.id), exactly: $0)
			}) {
				matches.append(wallpaper)
			}
		}
		return matches
	}

	private static func categoryCounts(
		in matches: [PresetWallpaper]
	) throws -> [WallpaperCategory?: Int] {
		var counts: [WallpaperCategory?: Int] = [nil: matches.count]
		for category in WallpaperCategory.allCases {
			counts[category] = 0
		}
		for wallpaper in matches {
			try Task.checkCancellation()
			counts[wallpaper.category, default: 0] += 1
		}
		return counts
	}

	private static func operatorCounts(
		among visibleWallpapers: [PresetWallpaper], avatars: [PresetAvatar]
	) throws -> [OperatorArtCount] {
		guard !avatars.isEmpty else { return [] }
		let namesByNormalizedTag = Dictionary(
			avatars.map { (PresetSearch.normalized($0.name), $0.name) },
			uniquingKeysWith: { first, _ in first }
		)
		var counts: [String: Int] = [:]
		for wallpaper in visibleWallpapers {
			try Task.checkCancellation()
			for tag in WallpaperTagCatalog.tags(for: wallpaper.id) {
				try Task.checkCancellation()
				guard namesByNormalizedTag[PresetSearch.normalized(tag)] != nil else { continue }
				counts[tag, default: 0] += 1
			}
		}
		return counts.compactMap { tag, count in
			namesByNormalizedTag[PresetSearch.normalized(tag)].map {
				OperatorArtCount(tag: tag, displayName: $0, count: count)
			}
		}
		.sorted { lhs, rhs in
			lhs.count != rhs.count
				? lhs.count > rhs.count
				: lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
		}
	}
}
