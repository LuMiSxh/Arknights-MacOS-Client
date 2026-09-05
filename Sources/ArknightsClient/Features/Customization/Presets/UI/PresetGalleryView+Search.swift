// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct PresetGallerySearchBar: View {
	let destination: PresetGalleryDestination
	let accentColor: Color
	@Binding var searchText: String
	@Binding var committedTags: [String]
	@FocusState private var isFocused: Bool

	private static let canonicalTags = Dictionary(
		WallpaperTagCatalog.shared.values.flatMap(\.self).map {
			(WallpaperSearch.normalized($0), $0)
		},
		uniquingKeysWith: { first, _ in first }
	)
	private static let contentHeight: CGFloat = 18

	var body: some View {
		HStack(spacing: 6) {
			Image(systemName: "magnifyingglass")
				.font(.caption)
				.foregroundStyle(isFocused ? accentColor : .secondary)
				.accessibilityHidden(true)

			if destination == .artwork {
				ForEach(committedTags, id: \.self) { tag in
					tagButton(tag)
				}
			}

			TextField(L10n.string(destination.searchPlaceholder), text: $searchText)
				.textFieldStyle(.plain)
				.focused($isFocused)
				.frame(height: Self.contentHeight)
				.accessibilityLabel(L10n.string(CustomizationStrings.searchLabel))
				.onKeyPress(.delete) {
					guard searchText.isEmpty, !committedTags.isEmpty else { return .ignored }
					committedTags.removeLast()
					return .handled
				}

			if !searchText.isEmpty || !committedTags.isEmpty {
				Button {
					searchText = ""
					committedTags = []
				} label: {
					Image(systemName: "xmark.circle.fill")
						.font(.callout)
						.imageScale(.large)
						.foregroundStyle(.secondary)
						.frame(width: Self.contentHeight, height: Self.contentHeight)
						.contentShape(Rectangle())
				}
				.buttonStyle(.plain)
				.accessibilityLabel(L10n.string(CustomizationStrings.searchClear))
			}
		}
		.font(.callout)
		.padding(.horizontal, 10)
		.padding(.vertical, 7)
		.adaptiveGlassEffect(
			tint: accentColor.opacity(isFocused ? 0.16 : 0.08),
			in: RoundedRectangle(cornerRadius: 10)
		)
		.overlay {
			RoundedRectangle(cornerRadius: 10)
				.strokeBorder(
					isFocused
						? accentColor.opacity(0.72)
						: LauncherVisuals.controlTint.opacity(0.16),
					lineWidth: isFocused ? 1.5 : 1
				)
				.allowsHitTesting(false)
		}
		.onChange(of: searchText) { _, _ in promoteTrailingTag() }
	}

	private func tagButton(_ tag: String) -> some View {
		Button {
			committedTags.removeAll { $0 == tag }
		} label: {
			HStack(spacing: 4) {
				Text(tag)
					.font(.caption.weight(.semibold))
					.lineLimit(1)
				Image(systemName: "xmark")
					.font(.system(size: 10, weight: .bold))
					.frame(width: Self.contentHeight, height: Self.contentHeight)
			}
			.padding(.leading, 8)
			.padding(.trailing, 4)
			.padding(.vertical, 3)
			.contentShape(Capsule())
		}
		.buttonStyle(.plain)
		.background(accentColor.opacity(0.22), in: .capsule)
		.overlay(Capsule().strokeBorder(accentColor.opacity(0.5), lineWidth: 1))
		.frame(height: Self.contentHeight)
		.accessibilityLabel(L10n.string(CustomizationStrings.searchRemoveTag(tag)))
	}

	private func promoteTrailingTag() {
		guard destination == .artwork, searchText.hasSuffix(" ") else { return }
		guard
			let (tag, remainingText) = WallpaperSearch.trailingKnownTag(
				in: searchText, canonicalTagsByNormalizedForm: Self.canonicalTags)
		else { return }

		searchText = remainingText
		if !committedTags.contains(tag) {
			committedTags.append(tag)
		}
	}
}

enum PresetGallerySearch {
	static func wallpapers(
		matching searchText: String,
		committedTags: [String],
		category: WallpaperCategory?,
		in wallpapers: [PresetWallpaper]
	) -> [PresetWallpaper] {
		PresetCatalogSearch.wallpapers(
			matching: searchText,
			category: category,
			in: matchingTags(committedTags, in: wallpapers)
		)
	}

	static func suggestions(
		matching searchText: String,
		committedTags: [String],
		category: WallpaperCategory?,
		in wallpapers: [PresetWallpaper]
	) -> [String] {
		let candidates = matchingTags(committedTags, in: wallpapers).filter {
			category == nil || $0.category == category
		}
		let committed = Set(committedTags.map(WallpaperSearch.normalized))
		return PresetCatalogSearch.wallpaperSuggestions(
			matching: searchText,
			in: candidates
		).filter { !committed.contains(WallpaperSearch.normalized($0)) }
	}

	private static func matchingTags(
		_ committedTags: [String], in wallpapers: [PresetWallpaper]
	) -> [PresetWallpaper] {
		wallpapers.filter { wallpaper in
			committedTags.allSatisfy {
				WallpaperSearch.tagsContain(
					WallpaperTagCatalog.tags(for: wallpaper.id), exactly: $0)
			}
		}
	}
}
