// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// The wallpaper gallery's search bar and its committed-tag pills.
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

	// Pins the text field and tag pills to an identical content height so committing a tag
	// never changes the search bar's overall height. Left to their own intrinsic sizes, a
	// pill (caption lineHeight 13 + 6pt vertical padding = 19pt) is measurably taller than
	// the text field (callout lineHeight 15pt), so the bar would visibly grow the instant
	// the first tag pill appears.
	private static let searchRowContentHeight: CGFloat = 18

	var searchBar: some View {
		HStack(spacing: 6) {
			Image(systemName: "magnifyingglass")
				.font(.caption)
				.foregroundStyle(isSearchFieldFocused ? customization.accentColor : .secondary)
				.accessibilityHidden(true)

			if destination == .artwork {
				ForEach(committedTags, id: \.self) { tag in tagPill(tag) }
			}

			TextField(L10n.string(destination.searchPlaceholder), text: $searchText)
				.textFieldStyle(.plain)
				.focused($isSearchFieldFocused)
				.frame(height: Self.searchRowContentHeight)
				.accessibilityLabel(L10n.string(CustomizationStrings.searchLabel))
				.onKeyPress(.delete) {
					// Backspace on an already-empty field pops the last pill — mirrors the
					// familiar chip-input behavior from Mail's To: field or Gmail's search bar.
					guard searchText.isEmpty, !committedTags.isEmpty else { return .ignored }
					committedTags.removeLast()
					return .handled
				}

			if !searchText.isEmpty || !committedTags.isEmpty {
				// Deliberately not a `Button`: on macOS, a `Button` wrapping only an `Image`
				// gets backed by a native control that hit-tests against the glyph's own
				// rendered (opaque) pixels, ignoring any `.contentShape()` override — no
				// frame or shape override on the label fixes that. A plain view with
				// `.onTapGesture` uses SwiftUI's own gesture recognition instead, which
				// does respect `.contentShape()` across its whole frame.
				Image(systemName: "xmark.circle.fill")
					.font(.callout)
					.imageScale(.large)
					.foregroundStyle(.secondary)
					.frame(width: Self.searchRowContentHeight, height: Self.searchRowContentHeight)
					.contentShape(Rectangle())
					.onTapGesture {
						searchText = ""
						committedTags = []
						lastAppliedSuggestionText = nil
					}
					.accessibilityAddTraits(.isButton)
					.accessibilityLabel(L10n.string(CustomizationStrings.searchClear))
			}
		}
		.font(.callout)
		.padding(.horizontal, 10)
		.padding(.vertical, 7)
		.adaptiveGlassEffect(
			tint: customization.accentColor.opacity(isSearchFieldFocused ? 0.16 : 0.08),
			in: RoundedRectangle(cornerRadius: 10)
		)
		.overlay {
			RoundedRectangle(cornerRadius: 10)
				.strokeBorder(
					isSearchFieldFocused
						? customization.accentColor.opacity(0.72)
						: LauncherVisuals.controlTint.opacity(0.16),
					lineWidth: isSearchFieldFocused ? 1.5 : 1
				)
				.allowsHitTesting(false)
		}
		.keyboardFocusIndicator(
			isFocused: isSearchFieldFocused, in: RoundedRectangle(cornerRadius: 8)
		)
		.onChange(of: searchText) { _, _ in promoteTrailingTagIfNeeded() }
	}

	private func tagPill(_ tag: String) -> some View {
		HStack(spacing: 4) {
			Text(tag)
				.font(.caption.weight(.semibold))
				.lineLimit(1)
			// Deliberately not a `Button` — see the search bar's clear button for why a
			// `Button` wrapping only an `Image` doesn't actually respect an enlarged
			// `.contentShape()` on macOS. `.onTapGesture` does.
			Image(systemName: "xmark")
				.font(.system(size: 10, weight: .bold))
				.frame(width: Self.searchRowContentHeight, height: Self.searchRowContentHeight)
				.contentShape(Rectangle())
				.onTapGesture {
					committedTags.removeAll { $0 == tag }
				}
				.accessibilityAddTraits(.isButton)
				.accessibilityLabel(L10n.string(CustomizationStrings.searchRemoveTag(tag)))
		}
		.padding(.leading, 8)
		.padding(.trailing, 4)
		.padding(.vertical, 3)
		.background(customization.accentColor.opacity(0.22), in: .capsule)
		.overlay(Capsule().strokeBorder(customization.accentColor.opacity(0.5), lineWidth: 1))
		.frame(height: Self.searchRowContentHeight)
	}

	// Wallpapers must carry every committed tag pill exactly before the free-text query is even
	// applied — otherwise a pill would just be one more prefix/substring term instead of pinning
	// down that exact tag. Shared by the grid, the type filter, and suggestions so all three
	// agree on which wallpapers are in play.
	private var tagFilteredWallpapers: [PresetWallpaper] {
		wallpapers.filter { wallpaper in
			committedTags.allSatisfy {
				WallpaperSearch.tagsContain(
					WallpaperTagCatalog.tags(for: wallpaper.id), exactly: $0)
			}
		}
	}

	var filteredWallpapers: [PresetWallpaper] {
		PresetCatalogSearch.wallpapers(
			matching: searchText, category: selectedCategory, in: tagFilteredWallpapers)
	}

	var wallpaperTerms: [String] {
		let categoryWallpapers = tagFilteredWallpapers.filter {
			selectedCategory == nil || $0.category == selectedCategory
		}
		let committedNormalized = Set(committedTags.map(WallpaperSearch.normalized))
		return PresetCatalogSearch.wallpaperSuggestions(
			matching: searchText, in: categoryWallpapers
		).filter { !committedNormalized.contains(WallpaperSearch.normalized($0)) }
	}

	// Promotes the just-completed trailing phrase of `searchText` into a tag pill once it's
	// followed by a space and spells out a complete, known tag — e.g. typing "w " (or picking
	// "w" from the suggestion row, which also appends a trailing space) moves "w" out of the
	// free-text field entirely rather than leaving it there to be prefix/fuzzy-matched like
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
}
