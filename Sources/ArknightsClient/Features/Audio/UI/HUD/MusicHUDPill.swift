// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// Morphs the now-playing HUD into an in-place controller without covering the launcher.
struct MusicHUDPill: View {
	@Bindable var settings: LauncherPreferencesController
	let musicTitle: String?
	let accentColor: Color
	let hudTintColor: Color
	let openCurrentMusicURL: () -> Void
	let controller: BackgroundMusicController
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@ScaledMetric(relativeTo: .caption) private var titleLineHeight =
		AppConstants.Music.titleLineHeight
	@ScaledMetric(relativeTo: .caption) private var collapsedPlayerHeight =
		AppConstants.Music.collapsedPlayerHeight
	@State private var isExpanded = false
	@State private var isHovering = false

	var body: some View {
		if let musicTitle {
			VStack(alignment: .leading, spacing: isExpanded ? 9 : 0) {
				Button(action: toggleExpansion) {
					HStack(spacing: 5) {
						Image(systemName: "music.note")
							.font(.caption2.weight(.semibold))
							.foregroundStyle(accentColor)
							.accessibilityHidden(true)
						VStack(alignment: .leading, spacing: 1) {
							OverflowingMusicTitle(title: musicTitle)
								.font(.caption.monospaced().weight(.medium))
								.foregroundStyle(isHovering ? .primary : .secondary)
								.frame(
									height: titleLineHeight,
									alignment: .leading
								)
								.frame(
									maxWidth: isExpanded
										? .infinity
										: AppConstants.Music.collapsedTitleMaxWidth,
									alignment: .leading
								)
							if isExpanded {
								Text(playbackStatus)
									.font(.caption)
									.foregroundStyle(accentColor)
									.transition(.opacity)
							}
						}
						Spacer(minLength: 6)
						Image(systemName: isExpanded ? "chevron.down" : "slider.horizontal.3")
							.font(.caption.bold())
							.foregroundStyle(accentColor.opacity(isHovering ? 1 : 0.65))
							.contentTransition(
								reduceMotion ? .identity : .symbolEffect(.replace)
							)
							.accessibilityHidden(true)
					}
					.contentShape(Rectangle())
				}
				.buttonStyle(.plain)
				.keyboardFocusIndicator(
					in: RoundedRectangle(cornerRadius: 8)
				)
				.onHover { isHovering = $0 }
				.accessibilityLabel(
					L10n.string(isExpanded ? AudioStrings.hideControls : AudioStrings.showControls)
				)
				.accessibilityValue(Text(musicTitle))
				.help(
					L10n.string(
						isExpanded ? AudioStrings.hideControls : AudioStrings.showControls
					)
				)

				if isExpanded {
					HStack(spacing: 6) {
						if controller.canNavigatePlaylist {
							MusicPlayerControlButton(
								title: L10n.string(AudioStrings.previousTrack),
								systemImage: "backward.end.fill",
								accentColor: accentColor,
								isDisabled: controller.controlsAreDisabled,
								action: controller.playPreviousTrack
							)
						}

						MusicPlayerControlButton(
							title: L10n.string(
								controller.isPlaying ? AudioStrings.pause : AudioStrings.play
							),
							systemImage: controller.isPlaying ? "pause.fill" : "play.fill",
							accentColor: accentColor,
							isProminent: true,
							isDisabled: controller.controlsAreDisabled,
							action: controller.togglePlayback
						)

						if controller.canNavigatePlaylist {
							MusicPlayerControlButton(
								title: L10n.string(AudioStrings.nextTrack),
								systemImage: "forward.end.fill",
								accentColor: accentColor,
								isDisabled: controller.controlsAreDisabled,
								action: controller.playNextTrack
							)
						}

						MusicVolumeControl(
							volume: $settings.launcherMusicVolume,
							accentColor: accentColor,
							isMuted: controller.isMuted,
							isDisabled: controller.controlsAreDisabled,
							toggleMute: controller.toggleMute
						)

						Spacer(minLength: 0)

						MusicPlayerControlButton(
							title: L10n.string(AudioStrings.openYouTube),
							systemImage: "arrow.up.right.square",
							accentColor: accentColor,
							isDisabled: controller.controlsAreDisabled,
							action: openCurrentMusicURL
						)
					}
					.frame(maxWidth: .infinity, alignment: .leading)
					.transition(expandedContentTransition)
				}
			}
			.padding(.horizontal, isExpanded ? 14 : 12)
			.padding(.vertical, isExpanded ? 11 : 0)
			.frame(width: isExpanded ? AppConstants.Music.expandedPlayerWidth : nil)
			.frame(
				minHeight: isExpanded
					? AppConstants.Music.expandedPlayerHeight
					: collapsedPlayerHeight,
				alignment: isExpanded ? .topLeading : .center
			)
			.frame(
				maxWidth: AppConstants.Music.expandedPlayerWidth
			)
			.fixedSize(horizontal: !isExpanded, vertical: false)
			.adaptiveGlassEffect(
				tint: hudTintColor,
				in: RoundedRectangle(cornerRadius: isExpanded ? 20 : 40)
			)
			.shadow(
				color: Color.black.opacity(isExpanded ? 0.35 : 0),
				radius: isExpanded ? 12 : 0,
				y: isExpanded ? 5 : 0
			)
			.accessibilityElement(children: .contain)
		}
	}

	private var playbackStatus: String {
		if controller.isGameProcessRunning { return L10n.string(AudioStrings.pausedForGame) }
		if controller.isChangingTrack { return L10n.string(AudioStrings.changingTrack) }
		return L10n.string(controller.isPlaying ? AudioStrings.playing : AudioStrings.paused)
	}

	private var expandedContentTransition: AnyTransition {
		if reduceMotion { return .opacity }
		return .opacity.combined(with: .scale(scale: 0.96, anchor: .topTrailing))
	}

	private func toggleExpansion() {
		withAnimation(
			reduceMotion
				? nil
				: .snappy(
					duration: AppConstants.Music.playerExpansionDuration,
					extraBounce: 0.04
				)
		) {
			isExpanded.toggle()
		}
	}
}
