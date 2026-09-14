// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// The operator icon grid shown in the Operator gallery.
struct PresetAvatarGrid: View {
	let catalog: PresetCatalogService
	let accentColor: Color
	let avatars: [PresetAvatar]
	let applyingItemID: String?
	let onSelect: (PresetAvatar) -> Void

	private let columns = [
		GridItem(.adaptive(minimum: 120, maximum: 140), spacing: 16)
	]

	var body: some View {
		LazyVGrid(columns: columns, spacing: 18) {
			ForEach(avatars) { avatar in
				let isApplying = applyingItemID == avatar.id
				Button {
					onSelect(avatar)
				} label: {
					VStack(spacing: 6) {
						ZStack {
							CachedPresetImage(
								catalog: catalog,
								url: avatar.url,
								cacheKey: avatar.id,
								contentMode: .fit,
								placeholderIcon: "person.crop.square"
							)
							.frame(width: 104, height: 104)
							.background(
								LinearGradient(
									colors: [
										Color(red: 0.16, green: 0.17, blue: 0.19),
										Color(red: 0.06, green: 0.06, blue: 0.07),
									],
									startPoint: .top,
									endPoint: .bottom
								)
							)
							.clipShape(RoundedRectangle(cornerRadius: 22))
							if isApplying {
								ZStack {
									Color.black.opacity(0.65)
									ProgressView()
										.controlSize(.small)
										.tint(accentColor)
								}
								.clipShape(RoundedRectangle(cornerRadius: 22))
							}
						}
						.frame(width: 104, height: 104)
						.overlay {
							RoundedRectangle(cornerRadius: 22)
								.strokeBorder(
									isApplying ? accentColor : Color.white.opacity(0.14),
									lineWidth: isApplying ? 2.5 : 1.5
								)
						}
						.shadow(
							color: isApplying ? accentColor.opacity(0.5) : Color.black.opacity(0.4),
							radius: isApplying ? 8 : 5,
							x: 0,
							y: 3
						)
						Text(avatar.name)
							.font(.caption.weight(isApplying ? .bold : .medium))
							.lineLimit(2)
							.truncationMode(.tail)
							.foregroundStyle(isApplying ? accentColor : .primary)
							.frame(maxWidth: 130)
					}
					.padding(.vertical, 4)
					.frame(maxWidth: .infinity)
					.contentShape(Rectangle())
				}
				.buttonStyle(.plain)
				.keyboardFocusIndicator(in: RoundedRectangle(cornerRadius: 22))
				.disabled(applyingItemID != nil)
				.accessibilityLabel(avatar.name)
				.accessibilityHint(
					L10n.string(CustomizationStrings.operatorApplyHelp(avatar.name))
				)
				.accessibilityValue(
					isApplying ? Text(L10n.string(CustomizationStrings.applying)) : Text("")
				)
			}
		}
	}
}

/// The official wallpaper grid shown in the Artwork gallery.
struct PresetWallpaperGrid: View {
	let catalog: PresetCatalogService
	let accentColor: Color
	let wallpapers: [PresetWallpaper]
	let applyingItemID: String?
	let onSelect: (PresetWallpaper) -> Void

	private let columns = [
		GridItem(.flexible(), spacing: 14),
		GridItem(.flexible(), spacing: 14),
		GridItem(.flexible(), spacing: 14),
	]

	var body: some View {
		LazyVGrid(columns: columns, spacing: 14) {
			ForEach(wallpapers) { wp in
				let isApplying = applyingItemID == wp.id
				Button {
					onSelect(wp)
				} label: {
					VStack(alignment: .leading, spacing: 6) {
						ZStack {
							CachedPresetImage(
								catalog: catalog,
								url: wp.thumbnailURL ?? wp.url,
								cacheKey: "thumb_\(wp.id)",
								contentMode: .fill,
								placeholderIcon: "photo"
							)
							.frame(minWidth: 0, maxWidth: .infinity)
							.frame(height: 105)
							.clipped()
							.clipShape(RoundedRectangle(cornerRadius: 10))
							if isApplying {
								ZStack {
									Color.black.opacity(0.68)
									VStack(spacing: 6) {
										ProgressView()
											.controlSize(.regular)
											.tint(accentColor)
										Text(L10n.string(CustomizationStrings.applying))
											.font(.caption2.bold())
											.foregroundStyle(.white)
									}
								}
								.clipShape(RoundedRectangle(cornerRadius: 10))
							}
						}
						.frame(height: 105)
						.background(Color.white.opacity(0.05), in: .rect(cornerRadius: 10))
						Text(wp.displayTitle)
							.font(.caption.weight(isApplying ? .bold : .medium))
							.lineLimit(2)
							.truncationMode(.tail)
							.foregroundStyle(isApplying ? accentColor : .primary)
					}
					.padding(8)
					.frame(maxWidth: .infinity)
					.background(
						isApplying ? accentColor.opacity(0.12) : Color.white.opacity(0.03),
						in: .rect(cornerRadius: 12)
					)
					.overlay {
						RoundedRectangle(cornerRadius: 12)
							.strokeBorder(
								isApplying ? accentColor : Color.white.opacity(0.07),
								lineWidth: isApplying ? 2 : 1
							)
					}
					.shadow(
						color: isApplying ? accentColor.opacity(0.4) : .clear,
						radius: 8,
						x: 0,
						y: 2
					)
				}
				.buttonStyle(.plain)
				.keyboardFocusIndicator(in: RoundedRectangle(cornerRadius: 12))
				.disabled(applyingItemID != nil)
				.accessibilityLabel(wp.displayTitle)
				.accessibilityHint(
					L10n.string(CustomizationStrings.wallpaperApplyHelp(wp.displayTitle))
				)
				.accessibilityValue(
					isApplying ? Text(L10n.string(CustomizationStrings.applying)) : Text("")
				)
				.help(hoverText(for: wp))
			}
		}
	}

	private func hoverText(for wp: PresetWallpaper) -> String {
		let tags = WallpaperTagCatalog.tags(for: wp.id).joined(separator: ", ")
		return [
			wp.author.map { L10n.string(CustomizationStrings.wallpaperHoverArtist($0)) },
			tags.isEmpty ? nil : L10n.string(CustomizationStrings.wallpaperHoverTags(tags)),
			wp.description,
		]
		.compactMap { $0 }
		.joined(separator: "\n")
	}
}
