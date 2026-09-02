// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// The wallpaper gallery's search bar, tag pills, autocomplete row, and type filter.
extension PresetGalleryView {
	// Every curated tag value keyed by its normalized form, computed once from the bundled
	// manifest — lets us recover the properly-spelled tag (e.g. "młynar", not "mlynar") to
	// display as a pill from whatever casing/diacritics the user actually typed, and doubles
	// as the membership set for "is this query already a complete, known tag" checks.
	private static let canonicalTagsByNormalizedForm: [String: String] = Dictionary(
		WallpaperTagCatalog.shared.values.flatMap(\.self).map {
			(WallpaperSearch.normalized($0), $0)
		},
		uniquingKeysWith: { first, _ in first }
	)
	static var allKnownTags: Set<String> { Set(canonicalTagsByNormalizedForm.keys) }

	var searchBar: some View {
		HStack(spacing: 6) {
			Image(systemName: "magnifyingglass")
				.font(.caption)
				.foregroundStyle(isSearchFieldFocused ? model.accentColor : .secondary)
				.accessibilityHidden(true)

			if destination == .artwork {
				ForEach(committedTags, id: \.self) { tag in tagPill(tag) }
			}

			TextField(destination.searchPlaceholder, text: $searchText)
				.textFieldStyle(.plain)
				.focused($isSearchFieldFocused)
				.accessibilityLabel("Search gallery")
				.onKeyPress(.delete) {
					// Backspace on an already-empty field pops the last pill — mirrors the
					// familiar chip-input behavior from Mail's To: field or Gmail's search bar.
					guard searchText.isEmpty, !committedTags.isEmpty else { return .ignored }
					committedTags.removeLast()
					return .handled
				}

			if !searchText.isEmpty || !committedTags.isEmpty {
				Button {
					searchText = ""
					committedTags = []
					lastAppliedSuggestionText = nil
				} label: {
					Image(systemName: "xmark.circle.fill")
						.font(.caption)
						.foregroundStyle(.secondary)
						// Enlarges the tap target without enlarging the icon's own layout
						// size — padding here would make the bar visibly grow the moment
						// this button appears (i.e. the instant there's something to clear).
						.contentShape(Rectangle().inset(by: -6))
				}
				.buttonStyle(.plain)
				.accessibilityLabel("Clear search")
			}
		}
		.font(.callout)
		.padding(.horizontal, 10)
		.padding(.vertical, 7)
		.themedInputSurface(accentColor: model.accentColor, isFocused: isSearchFieldFocused)
		.onChange(of: searchText) { _, _ in promoteTrailingTagIfNeeded() }
	}

	private func tagPill(_ tag: String) -> some View {
		HStack(spacing: 4) {
			Text(tag)
				.font(.caption.weight(.semibold))
				.lineLimit(1)
			Button {
				committedTags.removeAll { $0 == tag }
			} label: {
				Image(systemName: "xmark")
					.font(.system(size: 8, weight: .bold))
			}
			.buttonStyle(.plain)
			.contentShape(Rectangle().inset(by: -5))
		}
		.padding(.leading, 8)
		.padding(.trailing, 4)
		.padding(.vertical, 3)
		.background(model.accentColor.opacity(0.22), in: .capsule)
		.overlay(Capsule().strokeBorder(model.accentColor.opacity(0.5), lineWidth: 1))
	}

	// Promotes the just-completed trailing phrase of `searchText` into a tag pill once it's
	// followed by a space and spells out a complete, known tag — e.g. typing "w " (or picking
	// "w" from the suggestion row, which also appends a trailing space) moves "w" out of the
	// free-text field entirely rather than leaving it there to be prefix/substring-matched like
	// prose. Recognizes multi-word tags too ("blue poison "), not just the single last word.
	private func promoteTrailingTagIfNeeded() {
		guard destination == .artwork, searchText.hasSuffix(" ") else { return }
		guard
			let (canonical, remaining) = WallpaperSearch.trailingKnownTag(
				in: searchText, canonicalTagsByNormalizedForm: Self.canonicalTagsByNormalizedForm)
		else { return }
		searchText = remaining
		if !committedTags.contains(canonical) {
			committedTags.append(canonical)
		}
	}

	var searchSuggestions: [String] {
		guard searchText != lastAppliedSuggestionText else { return [] }
		let committedNormalized = Set(committedTags.map(WallpaperSearch.normalized))
		let candidates = wallpapers.compactMap(wallpaperEntry(for:))
		return WallpaperSearch.suggestions(
			for: searchText,
			wallpapers: candidates,
			knownTags: Self.allKnownTags
		)
		.filter { !committedNormalized.contains(WallpaperSearch.normalized($0)) }
	}

	func selectSuggestion(_ suggestion: String) {
		let updated = WallpaperSearch.applyingSuggestion(suggestion, to: searchText)
		searchText = updated
		lastAppliedSuggestionText = updated
	}

	var searchSuggestionsRow: some View {
		ScrollView(.horizontal, showsIndicators: false) {
			HStack(spacing: 8) {
				ForEach(searchSuggestions, id: \.self) { suggestion in
					Button {
						selectSuggestion(suggestion)
					} label: {
						Text(suggestion)
							.font(.caption.weight(.medium))
							.lineLimit(1)
							.padding(.horizontal, 10)
							.padding(.vertical, 5)
							.background(Color.white.opacity(0.06), in: .capsule)
							.overlay(
								Capsule().strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
							)
							.contentShape(.capsule)
					}
					.buttonStyle(.plain)
					// The enclosing horizontal ScrollView's own click/drag recognizer can
					// otherwise win the hit-test over a plain Button on macOS; claiming
					// priority here guarantees the tap reaches the chip.
					.highPriorityGesture(
						TapGesture().onEnded { selectSuggestion(suggestion) }
					)
				}
			}
		}
		.scrollClipDisabled()
	}

	private var categoryCounts: [WallpaperCategory: Int] {
		Dictionary(grouping: wallpapers, by: \.category).mapValues(\.count)
	}

	var categoryFilter: some View {
		Menu {
			Button("All Types (\(wallpapers.count))") { selectedCategory = nil }
			ForEach(WallpaperCategory.allCases) { category in
				Button("\(category.rawValue) (\(categoryCounts[category, default: 0]))") {
					selectedCategory = category
				}
			}
		} label: {
			Text(selectedCategory?.rawValue ?? "All Types")
				.lineLimit(1)
				.font(.callout)
				.padding(.horizontal, 10)
				.padding(.vertical, 7)
				.themedInputSurface(accentColor: model.accentColor, isFocused: false)
		}
		.menuStyle(.borderlessButton)
		.fixedSize()
	}

	var filteredWallpapers: [PresetWallpaper] {
		let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
		return wallpapers.filter { wallpaper in
			guard wallpaperEntry(for: wallpaper) != nil else { return false }
			return WallpaperSearch.matches(
				title: wallpaper.title,
				tags: WallpaperTagCatalog.tags(for: wallpaper.id),
				category: wallpaper.category,
				query: query,
				selectedCategory: selectedCategory,
				knownTags: Self.allKnownTags
			)
		}
	}

	// Pairs a wallpaper's title with its tags, or `nil` if it doesn't carry every committed
	// tag pill — shared by `filteredWallpapers` and `searchSuggestions` so both agree on which
	// wallpapers are even in play before applying the free-text query on top.
	private func wallpaperEntry(
		for wallpaper: PresetWallpaper
	) -> (title: String, tags: [String])? {
		let tags = WallpaperTagCatalog.tags(for: wallpaper.id)
		guard committedTags.allSatisfy({ WallpaperSearch.tagsContain(tags, exactly: $0) }) else {
			return nil
		}
		return (title: wallpaper.title, tags: tags)
	}
}
