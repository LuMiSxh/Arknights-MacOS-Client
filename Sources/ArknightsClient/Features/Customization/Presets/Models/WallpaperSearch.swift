// SPDX-License-Identifier: MPL-2.0

import Foundation

/// Pure matching logic for the wallpaper gallery's search box and its autocomplete row, kept
/// out of `PresetGalleryView` so it can be unit-tested without a live view hierarchy.
enum WallpaperSearch {
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
	) -> [String] {
		guard query.last?.isWhitespace != true else { return [] }
		let terms = query.split(whereSeparator: \.isWhitespace).map(String.init)
		guard let lastTerm = terms.last, !lastTerm.isEmpty else { return [] }
		let earlierTerms = terms.dropLast()

		let candidates =
			earlierTerms.isEmpty
			? wallpapers
			: wallpapers.filter { wallpaper in
				earlierTerms.allSatisfy {
					matchesTerm(
						$0, title: wallpaper.title, tags: wallpaper.tags, knownTags: knownTags)
				}
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
			for tag in wallpaper.tags
			where matchesCandidate(tag) && seen.insert(normalized(tag)).inserted {
				tagSuggestions.append(tag)
			}
		}
		for wallpaper in candidates {
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

	/// Finds the longest trailing run of words in `query` that together spell out a complete
	/// known tag — checking only the single last word would never recognize a multi-word tag
	/// like "blue poison" (splitting on whitespace breaks it into "blue" and "poison" before
	/// any lookup happens), so this tries the whole trailing phrase first and shrinks by one
	/// word at a time until a match is found.
	///
	/// Returns the matched canonical tag and `query` with that trailing phrase removed (with a
	/// trailing space preserved if anything remains before it), or `nil` if nothing matches.
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

	/// Whether `tags` contains `tag` exactly (case/diacritic-insensitive) — committed tag
	/// pills require an exact match by design, since a prefix match is what free-text terms
	/// are for; a pill exists specifically to pin down one exact tag.
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
}
