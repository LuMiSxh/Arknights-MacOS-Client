// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import SwiftUI

private let applyingLabel = "Applying…"

struct PresetAvatarGrid: View {
	@Environment(\.launcherTheme) private var theme
	let catalog: PresetCatalogService
	let accentColor: Color
	let avatars: [PresetAvatar]
	let applyingItemID: String?
	let onSelect: (PresetAvatar) -> Void

	private let columns = [
		GridItem(.adaptive(minimum: 120, maximum: 140), spacing: 16)
	]

	var body: some View {
		LazyVGrid(columns: columns, spacing: 16) {
			ForEach(avatars) { avatar in
				let isApplying = applyingItemID == avatar.id
				let isBlocked = applyingItemID != nil && !isApplying
				Button {
					onSelect(avatar)
				} label: {
					VStack(spacing: 8) {
						ZStack {
							CachedPresetImage(
								catalog: catalog,
								url: avatar.url,
								cacheKey: avatar.id,
								contentMode: .fit,
								placeholderIcon: "person.crop.square"
							)
							.frame(width: 104, height: 104)
							.background(theme.groupFill)
							.clipShape(RoundedRectangle(cornerRadius: LauncherVisuals.Radius.panel))
							if isApplying {
								ZStack {
									Color.black.opacity(0.65)
									ProgressView()
										.controlSize(.small)
										.tint(theme.accentFill)
								}
								.clipShape(
									RoundedRectangle(cornerRadius: LauncherVisuals.Radius.panel))
							}
						}
						.frame(width: 104, height: 104)
						.overlay {
							RoundedRectangle(cornerRadius: LauncherVisuals.Radius.panel)
								.strokeBorder(
									isApplying ? theme.accentFill : theme.hairline,
									lineWidth: LauncherVisuals.Control.borderWidth
								)
						}
						.shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
						Text(avatar.name)
							.font(.caption.weight(.medium))
							.lineLimit(2)
							.truncationMode(.tail)
							.foregroundStyle(isApplying ? theme.accentInk : theme.textPrimary)
							.frame(maxWidth: 128)
					}
					.padding(.vertical, 4)
					.frame(maxWidth: .infinity)
					.contentShape(Rectangle())
					.opacity(isBlocked ? 0.46 : 1)
				}
				.buttonStyle(ActionPressStyle(intensity: .subtle))
				.keyboardFocusIndicator(
					in: RoundedRectangle(cornerRadius: LauncherVisuals.Radius.panel)
				)
				.disabled(applyingItemID != nil)
				.accessibilityLabel(avatar.name)
				.accessibilityHint(
					applyHint(for: avatar)
				)
				.accessibilityValue(
					isApplying ? Text(applyingLabel) : Text("")
				)
			}
		}
	}

	private func applyHint(for avatar: PresetAvatar) -> String {
		"Use \(avatar.name) for both Dock icons"
	}
}

struct PresetWallpaperGrid: View {
	@Environment(\.launcherTheme) private var theme
	let catalog: PresetCatalogService
	let accentColor: Color
	let wallpapers: [PresetWallpaper]
	let applyingItemID: String?
	let onSelect: (PresetWallpaper) -> Void

	private let columns = [
		GridItem(.flexible(), spacing: 16),
		GridItem(.flexible(), spacing: 16),
		GridItem(.flexible(), spacing: 16),
	]
	// Nested radius: the card radius minus the card's padding.
	private let thumbnailRadius: CGFloat =
		LauncherVisuals.Radius.panel - LauncherTokens.Spacing.control

	var body: some View {
		LazyVGrid(columns: columns, spacing: 16) {
			ForEach(wallpapers) { wp in
				let isApplying = applyingItemID == wp.id
				let isBlocked = applyingItemID != nil && !isApplying
				Button {
					onSelect(wp)
				} label: {
					VStack(alignment: .leading, spacing: 8) {
						ZStack {
							CachedPresetImage(
								catalog: catalog,
								url: wp.thumbnailURL ?? wp.url,
								cacheKey: "thumb_\(wp.id)",
								contentMode: .fill,
								placeholderIcon: "photo"
							)
							.frame(minWidth: 0, maxWidth: .infinity)
							.frame(height: 104)
							.clipped()
							.clipShape(RoundedRectangle(cornerRadius: thumbnailRadius))
							if isApplying {
								ZStack {
									Color.black.opacity(0.65)
									VStack(spacing: 8) {
										ProgressView()
											.controlSize(.regular)
											.tint(theme.accentFill)
										Text(applyingLabel)
											.font(.caption2.weight(.medium))
											.foregroundStyle(.white)
									}
								}
								.clipShape(RoundedRectangle(cornerRadius: thumbnailRadius))
							}
						}
						.frame(height: 104)
						.background(
							theme.trackFill, in: .rect(cornerRadius: thumbnailRadius))
						Text(wp.displayTitle)
							.font(.caption.weight(.medium))
							.lineLimit(2)
							.truncationMode(.tail)
							.foregroundStyle(isApplying ? theme.accentInk : theme.textPrimary)
					}
					.padding(LauncherTokens.Spacing.control)
					.frame(maxWidth: .infinity)
					.background(
						theme.groupFill,
						in: .rect(cornerRadius: LauncherVisuals.Radius.panel)
					)
					.overlay {
						RoundedRectangle(cornerRadius: LauncherVisuals.Radius.panel)
							.strokeBorder(
								isApplying ? theme.accentFill : theme.hairline,
								lineWidth: LauncherVisuals.Control.borderWidth
							)
					}
					.opacity(isBlocked ? 0.46 : 1)
				}
				.buttonStyle(ActionPressStyle(intensity: .subtle))
				.keyboardFocusIndicator(
					in: RoundedRectangle(cornerRadius: LauncherVisuals.Radius.panel)
				)
				.disabled(applyingItemID != nil)
				.accessibilityLabel(wp.displayTitle)
				.accessibilityHint(
					applyHint(for: wp)
				)
				.accessibilityValue(
					isApplying ? Text(applyingLabel) : Text("")
				)
				.help(hoverText(for: wp))
			}
		}
	}

	private func applyHint(for wp: PresetWallpaper) -> String {
		"Use \(wp.displayTitle) as the launcher background"
	}

	private func hoverText(for wp: PresetWallpaper) -> String {
		let tags = WallpaperTagCatalog.tags(for: wp.id).joined(separator: ", ")
		return [
			wp.author.map { "Artist: \($0)" },
			tags.isEmpty ? nil : "Tags: \(tags)",
			wp.description,
		]
		.compactMap { $0 }
		.joined(separator: "\n")
	}
}
