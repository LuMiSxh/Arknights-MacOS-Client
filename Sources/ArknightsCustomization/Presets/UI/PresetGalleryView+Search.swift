// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import SwiftUI

struct PresetGallerySearchBar: View {
	let destination: PresetGalleryDestination
	package let accentColor: Color
	@Binding var searchText: String
	@Binding var committedTags: [String]
	@FocusState private var isFocused: Bool

	private static var canonicalTags: [String: String] {
		Dictionary(
			WallpaperTagCatalog.shared.values.flatMap(\.self).map {
				(PresetSearch.normalized($0), $0)
			},
			uniquingKeysWith: { first, _ in first }
		)
	}
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
				.accessibilityLabel("Search gallery")
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
				.buttonStyle(ActionPressStyle())
				.accessibilityLabel("Clear search")
			}
		}
		.font(.callout)
		.padding(.horizontal, 10)
		.padding(.vertical, 7)
		.adaptiveControlSurface(
			tint: accentColor,
			borderOpacity: isFocused ? 0.62 : nil,
			in: Capsule()
		)
		.focusEffectDisabled(true)
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
					.font(LauncherVisuals.Typography.tagGlyph)
					.frame(width: Self.contentHeight, height: Self.contentHeight)
			}
			.adaptiveControlForeground(.secondary, disabledTint: .secondary.opacity(0.44))
			.padding(.leading, 8)
			.padding(.trailing, 4)
			.padding(.vertical, 3)
			.contentShape(Capsule())
			.adaptiveControlSurface(tint: LauncherVisuals.controlTint, in: Capsule())
		}
		.buttonStyle(ActionPressStyle())
		.keyboardFocusIndicator(in: Capsule())
		.frame(height: Self.contentHeight)
		.accessibilityLabel("Remove \(tag) tag")
	}

	private func promoteTrailingTag() {
		guard destination == .artwork, searchText.hasSuffix(" ") else { return }
		guard
			let (tag, remainingText) = PresetSearch.trailingKnownTag(
				in: searchText, canonicalTagsByNormalizedForm: Self.canonicalTags)
		else { return }

		searchText = remainingText
		if !committedTags.contains(tag) {
			committedTags.append(tag)
		}
	}
}
