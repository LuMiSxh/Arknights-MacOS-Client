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
				.adaptiveControlForeground(
					isFocused ? accentColor : .secondary,
					disabledTint: .secondary
				)
				.accessibilityHidden(true)

			if destination == .artwork {
				ForEach(committedTags, id: \.self) { tag in
					tagButton(tag)
				}
			}

			TextField(destination.searchPlaceholder, text: $searchText)
				.textFieldStyle(.plain)
				.focused($isFocused)
				.frame(height: Self.contentHeight)
				.accessibilityLabel(CustomizationStrings.searchLabel)
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
						.adaptiveControlForeground(.secondary, disabledTint: .secondary)
						.frame(width: Self.contentHeight, height: Self.contentHeight)
						.contentShape(Rectangle())
				}
				.buttonStyle(.plain)
				.accessibilityLabel(CustomizationStrings.searchClear)
			}
		}
		.font(.callout)
		.padding(.horizontal, 10)
		.padding(.vertical, 7)
		.adaptiveControlSurface(
			tint: isFocused || !committedTags.isEmpty ? accentColor : LauncherVisuals.controlTint,
			in: Capsule()
		)
		.keyboardFocusIndicator(isFocused: isFocused, in: Capsule())
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
			.adaptiveControlForeground(accentColor, disabledTint: accentColor.opacity(0.44))
			.padding(.leading, 8)
			.padding(.trailing, 4)
			.padding(.vertical, 3)
			.contentShape(Capsule())
		}
		.buttonStyle(.plain)
		.adaptiveControlSurface(tint: accentColor, in: Capsule())
		.keyboardFocusIndicator(in: Capsule())
		.frame(height: Self.contentHeight)
		.accessibilityLabel(CustomizationStrings.searchRemoveTag(tag))
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
				filteredAvatars: try await PresetCatalogSearch.avatars(
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
		try await PresetCatalogSearch.wallpapers(
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
		let committed = Set(committedTags.map(WallpaperSearch.normalized))
		let suggestions = try await PresetCatalogSearch.wallpaperSuggestions(
			matching: searchText,
			in: candidates
		)
		return suggestions.filter { !committed.contains(WallpaperSearch.normalized($0)) }
	}

	private static func matchingTags(
		_ committedTags: [String], in wallpapers: [PresetWallpaper]
	) throws -> [PresetWallpaper] {
		var matches: [PresetWallpaper] = []
		for wallpaper in wallpapers {
			try Task.checkCancellation()
			if committedTags.allSatisfy({
				WallpaperSearch.tagsContain(
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
			avatars.map { (WallpaperSearch.normalized($0.name), $0.name) },
			uniquingKeysWith: { first, _ in first }
		)
		var counts: [String: Int] = [:]
		for wallpaper in visibleWallpapers {
			try Task.checkCancellation()
			for tag in WallpaperTagCatalog.tags(for: wallpaper.id) {
				try Task.checkCancellation()
				guard namesByNormalizedTag[WallpaperSearch.normalized(tag)] != nil else { continue }
				counts[tag, default: 0] += 1
			}
		}
		return counts.compactMap { tag, count in
			namesByNormalizedTag[WallpaperSearch.normalized(tag)].map {
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
