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
	@Binding var isExpanded: Bool
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@ScaledMetric(relativeTo: .caption) private var titleLineHeight =
		AppConstants.Music.titleLineHeight
	@ScaledMetric(relativeTo: .caption) private var collapsedPlayerHeight =
		AppConstants.Music.collapsedPlayerHeight

	var body: some View {
		if let musicTitle {
			VStack(alignment: .leading, spacing: isExpanded ? 9 : 0) {
				Button(action: toggleExpansion) {
					HStack(spacing: 5) {
						Image(systemName: "music.note")
							.font(.caption2.weight(.semibold))
							.adaptiveControlForeground(accentColor)
							.accessibilityHidden(true)
						VStack(alignment: .leading, spacing: 1) {
							OverflowingMusicTitle(title: musicTitle)
								.font(.caption.monospaced().weight(.medium))
								.foregroundStyle(.secondary)
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
									.adaptiveControlForeground(accentColor)
									.transition(.opacity)
							}
						}
						Spacer(minLength: 6)
						Image(systemName: disclosureImage)
							.font(.caption.bold())
							.adaptiveControlForeground(accentColor)
							.contentTransition(
								HUDPillMotion.chevronTransition(reduceMotion: reduceMotion)
							)
							.accessibilityHidden(true)
					}
					.padding(.horizontal, isExpanded ? 14 : 12)
					.frame(minHeight: isExpanded ? nil : collapsedPlayerHeight)
					.contentShape(Rectangle())
				}
				.buttonStyle(ActionPressStyle())
				.keyboardFocusIndicator(in: Capsule())
				.accessibilityLabel(
					isExpanded ? AudioStrings.hideControls : AudioStrings.showControls
				)
				.accessibilityValue(Text(musicTitle))
				.help(

					isExpanded ? AudioStrings.hideControls : AudioStrings.showControls

				)

				if isExpanded {
					HStack(spacing: 6) {
						if controller.canNavigatePlaylist {
							MusicPlayerControlButton(
								title: AudioStrings.previousTrack,
								systemImage: "backward.end.fill",
								accentColor: accentColor,
								isDisabled: controller.controlsAreDisabled,
								action: controller.playPreviousTrack
							)
						}

						MusicPlayerControlButton(
							title:
								controller.isPlaying ? AudioStrings.pause : AudioStrings.play,
							systemImage: controller.isPlaying ? "pause.fill" : "play.fill",
							accentColor: accentColor,
							isProminent: true,
							isDisabled: controller.controlsAreDisabled,
							action: controller.togglePlayback
						)

						if controller.canNavigatePlaylist {
							MusicPlayerControlButton(
								title: AudioStrings.nextTrack,
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
							title: AudioStrings.openYouTube,
							systemImage: "arrow.up.right.square",
							accentColor: accentColor,
							isDisabled: controller.controlsAreDisabled,
							action: openCurrentMusicURL
						)
					}
					.padding(.horizontal, 14)
					.frame(maxWidth: .infinity, alignment: .leading)
					.transition(expandedContentTransition)
				}
			}
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
			.hudPillSurface(
				isExpanded: isExpanded,
				tint: hudTintColor,
				progressTint: accentColor
			)
			.shadow(
				color: Color.black.opacity(isExpanded ? 0.35 : 0),
				radius: isExpanded ? 12 : 0,
				y: isExpanded ? 5 : 0
			)
			.accessibilityElement(children: .contain)
			.onExitCommand(perform: collapseExpansion)
		}
	}

	private var playbackStatus: String {
		if controller.isGameProcessRunning { return AudioStrings.pausedForGame }
		if controller.isChangingTrack { return AudioStrings.changingTrack }
		return controller.isPlaying ? AudioStrings.playing : AudioStrings.paused
	}

	private var disclosureImage: String {
		isExpanded ? "chevron.up" : "chevron.down"
	}

	private var expandedContentTransition: AnyTransition {
		HUDPillMotion.expandedContentTransition(reduceMotion: reduceMotion)
	}

	private func toggleExpansion() {
		withAnimation(HUDPillMotion.expansionAnimation(reduceMotion: reduceMotion)) {
			isExpanded.toggle()
		}
	}

	private func collapseExpansion() {
		guard isExpanded else { return }
		withAnimation(HUDPillMotion.expansionAnimation(reduceMotion: reduceMotion)) {
			isExpanded = false
		}
	}
}
