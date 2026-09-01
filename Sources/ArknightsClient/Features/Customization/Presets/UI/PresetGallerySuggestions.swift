// SPDX-License-Identifier: MPL-2.0

import SwiftUI

private enum PresetGallerySuggestion: Identifiable {
	case avatar(PresetAvatar)
	case wallpaper(PresetWallpaper)

	var id: String {
		switch self {
		case .avatar(let avatar): "avatar_\(avatar.id)"
		case .wallpaper(let wallpaper): "wallpaper_\(wallpaper.id)"
		}
	}

	var title: String {
		switch self {
		case .avatar(let avatar): avatar.name
		case .wallpaper(let wallpaper): wallpaper.displayTitle
		}
	}

	var subtitle: String? {
		switch self {
		case .avatar: return nil
		case .wallpaper(let wallpaper): return wallpaper.author
		}
	}

	var accessibilityTitle: String {
		[title, subtitle].compactMap { $0 }.joined(separator: ", ")
	}

	var compactTitle: String {
		[title, subtitle].compactMap { $0 }.joined(separator: " · ")
	}
}

struct PresetGallerySuggestions: View {
	let destination: PresetGalleryDestination
	let avatars: [PresetAvatar]
	let wallpapers: [PresetWallpaper]
	let onSelect: (String) -> Void
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	private var suggestions: [PresetGallerySuggestion] {
		if destination == .artwork {
			return wallpapers.prefix(AppConstants.Presets.gallerySuggestionLimit).map {
				.wallpaper($0)
			}
		}
		return avatars.prefix(AppConstants.Presets.gallerySuggestionLimit).map { .avatar($0) }
	}

	var body: some View {
		ScrollView(.horizontal, showsIndicators: false) {
			HStack(spacing: 8) {
				ForEach(suggestions) { suggestion in
					PresetGallerySuggestionChip(
						destination: destination,
						suggestion: suggestion,
						onSelect: onSelect,
						reduceMotion: reduceMotion
					)
				}
			}
		}
		.scrollClipDisabled()
		.padding(.bottom, suggestions.isEmpty ? 0 : 8)
		.animation(
			reduceMotion ? nil : .easeInOut(duration: 0.2),
			value: suggestions.map(\.id)
		)
	}
}

private struct PresetGallerySuggestionChip: View {
	let destination: PresetGalleryDestination
	let suggestion: PresetGallerySuggestion
	let onSelect: (String) -> Void
	let reduceMotion: Bool

	private var transition: AnyTransition {
		guard !reduceMotion else { return .opacity }
		return .asymmetric(
			insertion: .move(edge: .trailing).combined(with: .opacity),
			removal: .move(edge: .leading).combined(with: .opacity)
		)
	}

	var body: some View {
		Button {
			onSelect(suggestion.title)
		} label: {
			HStack(spacing: 5) {
				Image(systemName: destination == .artwork ? "photo" : "person.crop.square")
					.foregroundStyle(.secondary)
				Text(suggestion.compactTitle)
					.font(.caption.weight(.medium))
					.lineLimit(1)
					.truncationMode(.tail)
			}
			.padding(.horizontal, 12)
			.padding(.vertical, 6)
			.frame(maxWidth: 220, alignment: .leading)
			.contentShape(Capsule())
			.adaptiveGlassEffect(in: Capsule())
			.overlay {
				Capsule()
					.strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
					.allowsHitTesting(false)
			}
		}
		.buttonStyle(.plain)
		.keyboardFocusIndicator(in: Capsule())
		.accessibilityLabel(Text(suggestion.accessibilityTitle))
		.accessibilityHint(Text(L10n.string(CustomizationStrings.searchSuggestionSelect)))
		.transition(transition)
	}
}
