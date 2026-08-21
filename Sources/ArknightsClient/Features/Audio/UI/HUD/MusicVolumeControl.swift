// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// Keeps volume secondary to playback: hovering or focusing reveals the level, while the
/// compact speaker remains a direct mute toggle and restores the last audible setting.
struct MusicVolumeControl: View {
	@Binding var volume: Double
	let accentColor: Color
	let isMuted: Bool
	let isDisabled: Bool
	let toggleMute: () -> Void
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@FocusState private var focusedElement: FocusedElement?
	@State private var isHovering = false

	var body: some View {
		HStack(spacing: 7) {
			Button(action: toggleMute) {
				Label(muteButtonTitle, systemImage: speakerSymbol)
					.labelStyle(.iconOnly)
					.font(.system(size: 13, weight: .semibold))
					.foregroundStyle(LauncherVisuals.controlTint)
					.frame(
						width: AppConstants.Music.secondaryControlDimension,
						height: AppConstants.Music.secondaryControlDimension
					)
					.contentShape(Circle())
			}
			.buttonStyle(.plain)
			.focused($focusedElement, equals: .speaker)
			.disabled(isDisabled)
			.accessibilityValue(isMuted ? "Muted" : volumeAccessibilityValue)
			.help(muteButtonTitle)

			if isExpanded {
				Slider(value: $volume, in: 0...1, step: 0.05)
					.tint(accentColor)
					.frame(width: AppConstants.Music.volumeSliderWidth)
					.focused($focusedElement, equals: .slider)
					.accessibilityLabel("Music volume")
					.accessibilityValue(volumeAccessibilityValue)
					.disabled(isDisabled)
					.transition(.opacity.combined(with: .move(edge: .leading)))
			}
		}
		.frame(
			width: isExpanded
				? AppConstants.Music.volumeControlExpandedWidth
				: AppConstants.Music.secondaryControlDimension,
			height: AppConstants.Music.secondaryControlDimension,
			alignment: .leading
		)
		.hudSecondaryControlSurface(in: Capsule())
		.contentShape(Capsule())
		.clipped()
		.opacity(isDisabled ? 0.38 : 1)
		.onHover { isHovering = $0 }
		.animation(
			reduceMotion
				? nil
				: .snappy(
					duration: AppConstants.Music.playerExpansionDuration,
					extraBounce: 0
				),
			value: isExpanded
		)
	}

	private var isExpanded: Bool {
		isHovering || focusedElement != nil
	}

	private var muteButtonTitle: String {
		isMuted ? "Unmute music" : "Mute music"
	}

	private var speakerSymbol: String {
		if isMuted { return "speaker.slash.fill" }
		return switch volume {
		case ...0: "speaker.fill"
		case ..<0.34: "speaker.wave.1.fill"
		case ..<0.67: "speaker.wave.2.fill"
		default: "speaker.wave.3.fill"
		}
	}

	private var volumeAccessibilityValue: String {
		"\(Int(volume * 100)) percent"
	}

	private enum FocusedElement: Hashable {
		case speaker
		case slider
	}
}
