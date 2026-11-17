// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import SwiftUI

private let applyingLabel = "Applying…"

private enum AvatarGridMetrics {
	static let minimumColumnWidth: CGFloat = 120
	static let maximumColumnWidth: CGFloat = 140
	static let labelWidth: CGFloat = 128
	static let shadowRadius: CGFloat = 4
	static let shadowYOffset: CGFloat = 2
}

struct PresetAvatarGrid: View {
	@Environment(\.launcherTheme) private var theme
	let catalog: PresetCatalogService
	let avatars: [PresetAvatar]
	let applyingItemID: String?
	let onSelect: (PresetAvatar) -> Void

	private let columns = [
		GridItem(
			.adaptive(
				minimum: AvatarGridMetrics.minimumColumnWidth,
				maximum: AvatarGridMetrics.maximumColumnWidth),
			spacing: LauncherTokens.Spacing.panel)
	]

	var body: some View {
		LazyVGrid(columns: columns, spacing: LauncherTokens.Spacing.panel) {
			ForEach(avatars) { avatar in
				let isApplying = applyingItemID == avatar.id
				let isBlocked = applyingItemID != nil && !isApplying
				Button {
					onSelect(avatar)
				} label: {
					VStack(spacing: LauncherTokens.Spacing.control) {
						ZStack {
							CachedPresetImage(
								catalog: catalog,
								url: avatar.url,
								cacheKey: avatar.id,
								contentMode: .fit,
								placeholderIcon: "person.crop.square"
							)
							.frame(
								width: LauncherTokens.Layout.presetAvatarTileSize,
								height: LauncherTokens.Layout.presetAvatarTileSize
							)
							.background(theme.groupFill)
							.clipShape(RoundedRectangle(cornerRadius: LauncherTokens.Radius.panel))
							if isApplying {
								ZStack {
									LauncherVisuals.opaqueDim.opacity(
										LauncherVisuals.Shade.loadingScrimOpacity)
									ProgressView()
										.controlSize(.small)
										.tint(theme.accentFill)
								}
								.clipShape(
									RoundedRectangle(cornerRadius: LauncherTokens.Radius.panel))
							}
						}
						.frame(
							width: LauncherTokens.Layout.presetAvatarTileSize,
							height: LauncherTokens.Layout.presetAvatarTileSize
						)
						.overlay {
							RoundedRectangle(cornerRadius: LauncherTokens.Radius.panel)
								.strokeBorder(
									isApplying ? theme.accentFill : theme.hairline,
									lineWidth: LauncherTokens.Control.borderWidth
								)
						}
						.shadow(
							color: LauncherVisuals.opaqueDim.opacity(
								LauncherVisuals.Shade.artworkShadowOpacity),
							radius: AvatarGridMetrics.shadowRadius,
							x: 0,
							y: AvatarGridMetrics.shadowYOffset)
						Text(avatar.name)
							.font(.caption.weight(.medium))
							.lineLimit(2)
							.truncationMode(.tail)
							.foregroundStyle(isApplying ? theme.accentInk : theme.textPrimary)
							.frame(maxWidth: AvatarGridMetrics.labelWidth)
					}
					.padding(.vertical, LauncherTokens.Spacing.compact)
					.frame(maxWidth: .infinity)
					.contentShape(Rectangle())
					.opacity(isBlocked ? LauncherVisuals.Control.blockedOpacity : 1)
				}
				.buttonStyle(ActionPressStyle(intensity: .subtle))
				.keyboardFocusIndicator(
					in: RoundedRectangle(cornerRadius: LauncherTokens.Radius.panel)
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
	let wallpapers: [PresetWallpaper]
	let applyingItemID: String?
	let onSelect: (PresetWallpaper) -> Void

	private let columns = [
		GridItem(.flexible(), spacing: LauncherTokens.Spacing.panel),
		GridItem(.flexible(), spacing: LauncherTokens.Spacing.panel),
		GridItem(.flexible(), spacing: LauncherTokens.Spacing.panel),
	]
	// Nested radius: the card radius minus the card's padding.
	private let thumbnailRadius: CGFloat =
		LauncherTokens.Radius.panel - LauncherTokens.Spacing.control

	var body: some View {
		LazyVGrid(columns: columns, spacing: LauncherTokens.Spacing.panel) {
			ForEach(wallpapers) { wp in
				let isApplying = applyingItemID == wp.id
				let isBlocked = applyingItemID != nil && !isApplying
				Button {
					onSelect(wp)
				} label: {
					VStack(alignment: .leading, spacing: LauncherTokens.Spacing.control) {
						ZStack {
							CachedPresetImage(
								catalog: catalog,
								url: wp.thumbnailURL ?? wp.url,
								cacheKey: "thumb_\(wp.id)",
								contentMode: .fill,
								placeholderIcon: "photo"
							)
							.frame(minWidth: 0, maxWidth: .infinity)
							.frame(height: LauncherTokens.Layout.presetThumbnailHeight)
							.clipped()
							.clipShape(RoundedRectangle(cornerRadius: thumbnailRadius))
							if isApplying {
								ZStack {
									LauncherVisuals.opaqueDim.opacity(
										LauncherVisuals.Shade.loadingScrimOpacity)
									VStack(spacing: LauncherTokens.Spacing.control) {
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
						.frame(height: LauncherTokens.Layout.presetThumbnailHeight)
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
						in: .rect(cornerRadius: LauncherTokens.Radius.panel)
					)
					.overlay {
						RoundedRectangle(cornerRadius: LauncherTokens.Radius.panel)
							.strokeBorder(
								isApplying ? theme.accentFill : theme.hairline,
								lineWidth: LauncherTokens.Control.borderWidth
							)
					}
					.opacity(isBlocked ? LauncherVisuals.Control.blockedOpacity : 1)
				}
				.buttonStyle(ActionPressStyle(intensity: .subtle))
				.keyboardFocusIndicator(
					in: RoundedRectangle(cornerRadius: LauncherTokens.Radius.panel)
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
