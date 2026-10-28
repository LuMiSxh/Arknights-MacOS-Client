// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import SwiftUI

/// Morphs the now-playing HUD into an in-place controller without covering the launcher.
package struct MusicHUDPill: View {
	@Bindable var settings: LauncherPreferencesController
	let musicTitle: String?
	package let accentColor: Color
	let hudTintColor: Color
	let openCurrentMusicURL: () -> Void
	let controller: BackgroundMusicController
	@Binding var isExpanded: Bool
	@ScaledMetric(relativeTo: .caption) private var titleLineHeight =
		AppConstants.Music.titleLineHeight
	@ScaledMetric(relativeTo: .caption) private var collapsedPlayerHeight =
		AppConstants.Music.collapsedPlayerHeight

	package init(
		settings: LauncherPreferencesController,
		musicTitle: String?,
		accentColor: Color,
		hudTintColor: Color,
		openCurrentMusicURL: @escaping () -> Void,
		controller: BackgroundMusicController,
		isExpanded: Binding<Bool>
	) {
		self.settings = settings
		self.musicTitle = musicTitle
		self.accentColor = accentColor
		self.hudTintColor = hudTintColor
		self.openCurrentMusicURL = openCurrentMusicURL
		self.controller = controller
		_isExpanded = isExpanded
	}

	package var body: some View {
		if let musicTitle {
			ExpandableHUDPill(
				systemImage: "music.note",
				iconFont: .caption2.weight(.semibold),
				toggleNoun: "music controls",
				accessibilityValue: musicTitle,
				accentColor: accentColor,
				hudTintColor: hudTintColor,
				expandedSpacing: 9,
				sizing: HUDPillSizing(
					collapsedHeight: collapsedPlayerHeight,
					collapsedMaxWidth: AppConstants.Music.expandedPlayerWidth,
					expandedWidth: AppConstants.Music.expandedPlayerWidth,
					expandedMaxWidth: AppConstants.Music.expandedPlayerWidth,
					expandedMinHeight: AppConstants.Music.expandedPlayerHeight
				),
				isExpanded: $isExpanded
			) {
				VStack(alignment: .leading, spacing: 1) {
					OverflowingMusicTitle(title: musicTitle)
						.font(.caption.monospaced().weight(.medium))
						.foregroundStyle(.secondary)
						.frame(height: titleLineHeight, alignment: .leading)
						.frame(
							maxWidth: isExpanded
								? .infinity
								: AppConstants.Music.collapsedTitleMaxWidth,
							alignment: .leading
						)
					if isExpanded {
						Text(playbackStatus)
							.font(.caption)
							.adaptiveControlForeground(accentColor)
							.transition(.opacity)
					}
				}
			} detail: {
				HStack(spacing: 6) {
					if controller.canNavigatePlaylist {
						MusicPlayerControlButton(
							title: "Previous Track",
							systemImage: "backward.end.fill",
							accentColor: accentColor,
							isDisabled: controller.controlsAreUnavailable,
							action: controller.playPreviousTrack
						)
					}

					MusicPlayerControlButton(
						title:
							controller.isPlaying ? "Pause" : "Play",
						systemImage: controller.isPlaying ? "pause.fill" : "play.fill",
						accentColor: accentColor,
						isProminent: true,
						isDisabled: controller.controlsAreUnavailable,
						action: controller.togglePlayback
					)

					if controller.canNavigatePlaylist {
						MusicPlayerControlButton(
							title: "Next Track",
							systemImage: "forward.end.fill",
							accentColor: accentColor,
							isDisabled: controller.controlsAreUnavailable,
							action: controller.playNextTrack
						)
					}

					MusicVolumeControl(
						volume: $settings.launcherMusicVolume,
						accentColor: accentColor,
						isMuted: controller.isMuted,
						isDisabled: controller.controlsAreUnavailable,
						toggleMute: controller.toggleMute
					)

					Spacer(minLength: 0)

					MusicPlayerControlButton(
						title: "Open on YouTube",
						systemImage: "arrow.up.right.square",
						accentColor: accentColor,
						isDisabled: controller.controlsAreUnavailable,
						action: openCurrentMusicURL
					)
				}
				.padding(.horizontal, 14)
				.frame(maxWidth: .infinity, alignment: .leading)
			}
		}
	}

	private var playbackStatus: String {
		if controller.isSilencedForGame { return "Paused while the game is running" }
		if controller.isUnavailable { return "Music unavailable" }
		if controller.isChangingTrack { return "Changing track…" }
		return controller.isPlaying ? "Playing" : "Paused"
	}
}
