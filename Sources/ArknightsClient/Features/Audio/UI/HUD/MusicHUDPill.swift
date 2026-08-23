// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// Morphs the now-playing HUD into an in-place controller without covering the launcher.
struct MusicHUDPill: View {
	@Bindable var model: LauncherViewModel
	var controller: BackgroundMusicController
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var isExpanded = false
	@State private var isHovering = false

	var body: some View {
		if let musicTitle = model.currentMusicTitle {
			VStack(alignment: .leading, spacing: isExpanded ? 9 : 0) {
				Button(action: toggleExpansion) {
					HStack(spacing: 5) {
						Image(systemName: "music.note")
							.font(.system(size: 10, weight: .semibold))
							.foregroundStyle(model.accentColor)
						VStack(alignment: .leading, spacing: 1) {
							OverflowingMusicTitle(title: musicTitle)
								.font(.system(size: 11, weight: .medium, design: .monospaced))
								.foregroundStyle(isHovering ? .primary : .secondary)
								.frame(
									height: AppConstants.Music.titleLineHeight,
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
									.foregroundStyle(model.accentColor)
									.transition(.opacity)
							}
						}
						Spacer(minLength: 6)
						Image(systemName: isExpanded ? "chevron.down" : "slider.horizontal.3")
							.font(.caption.bold())
							.foregroundStyle(model.accentColor.opacity(isHovering ? 1 : 0.65))
							.contentTransition(.symbolEffect(.replace))
							.accessibilityHidden(true)
					}
					.contentShape(Rectangle())
				}
				.buttonStyle(.plain)
				.onHover { isHovering = $0 }
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
								accentColor: model.accentColor,
								isDisabled: controller.controlsAreDisabled,
								action: controller.playPreviousTrack
							)
						}

						MusicPlayerControlButton(
							title: L10n.string(
								controller.isPlaying ? AudioStrings.pause : AudioStrings.play
							),
							systemImage: controller.isPlaying ? "pause.fill" : "play.fill",
							accentColor: model.accentColor,
							isProminent: true,
							isDisabled: controller.controlsAreDisabled,
							action: controller.togglePlayback
						)

						if controller.canNavigatePlaylist {
							MusicPlayerControlButton(
								title: L10n.string(AudioStrings.nextTrack),
								systemImage: "forward.end.fill",
								accentColor: model.accentColor,
								isDisabled: controller.controlsAreDisabled,
								action: controller.playNextTrack
							)
						}

						MusicVolumeControl(
							volume: $model.launcherMusicVolume,
							accentColor: model.accentColor,
							isMuted: controller.isMuted,
							isDisabled: controller.controlsAreDisabled,
							toggleMute: controller.toggleMute
						)

						Spacer(minLength: 0)

						MusicPlayerControlButton(
							title: L10n.string(AudioStrings.openYouTube),
							systemImage: "arrow.up.right.square",
							accentColor: model.accentColor,
							isDisabled: controller.controlsAreDisabled,
							action: model.openCurrentMusicURL
						)
					}
					.frame(maxWidth: .infinity, alignment: .leading)
					.transition(expandedContentTransition)
				}
			}
			.padding(.horizontal, isExpanded ? 14 : 12)
			.padding(.vertical, isExpanded ? 11 : 0)
			.frame(
				width: isExpanded ? AppConstants.Music.expandedPlayerWidth : nil,
				height: isExpanded
					? AppConstants.Music.expandedPlayerHeight
					: AppConstants.Music.collapsedPlayerHeight,
				alignment: isExpanded ? .topLeading : .center
			)
			.frame(
				maxWidth: isExpanded
					? AppConstants.Music.expandedPlayerWidth
					: AppConstants.Music.collapsedPlayerMaxWidth
			)
			.fixedSize(horizontal: !isExpanded, vertical: false)
			.clipped()
			.adaptiveGlassEffect(
				tint: model.hudTintColor,
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
		if model.isGameProcessRunning { return L10n.string(AudioStrings.pausedForGame) }
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
