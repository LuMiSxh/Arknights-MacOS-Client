// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import SwiftUI

/// The fullscreen resolution picker for `GameDisplaySettingsPanel`.
struct GameFullscreenResolutionRow: View {
	@Bindable var settings: LauncherPreferencesController
	let nativeFullscreenSize: GameDisplaySize?
	let isDisabled: Bool

	private var options: GameLaunchOptions { settings.launchOptions }

	private static let nativeResolution = "Native"

	var body: some View {
		var resolutions = GameFullscreenResolution.choices(native: nativeFullscreenSize)
		// Keeps a resolution saved for another display selectable.
		if !resolutions.contains(options.fullscreenResolution) {
			resolutions.append(options.fullscreenResolution)
		}
		let choices = resolutions.map { ($0, resolutionChoiceTitle($0)) }
		return SettingsActionRow(
			title: "Resolution",
			help:
				"Fullscreen fills the display with the menu bar. Native matches that display exactly; lower resolutions are scaled up to fill it. With MetalFX or Standard rendering, the game draws one pixel per point, fewer pixels than the resolution on a Retina display, so every resolution needs less graphics power."
		) {
			GlassMenuPicker(
				selection: fullscreenResolution,
				options: choices,
				isDisabled: isDisabled
			)
		}
	}

	private func resolutionChoiceTitle(_ choice: GameFullscreenResolution) -> String {
		switch choice {
		case .native:
			// For example "Native (6016 × 3384)", like games label the display's own resolution.
			nativeFullscreenSize.map { "\(Self.nativeResolution) (\($0.displayName))" }
				?? Self.nativeResolution
		case .fixed(let size): resolutionTitle(size)
		}
	}

	private var fullscreenResolution: Binding<GameFullscreenResolution> {
		Binding(
			get: { options.fullscreenResolution },
			set: { settings.launchOptions.selectFullscreen($0, native: nativeFullscreenSize) }
		)
	}

	/// For example "2560 × 1440 (WQHD)"; resolutions without a common name stay plain.
	private func resolutionTitle(_ size: GameDisplaySize) -> String {
		size.commonName.map { "\(size.displayName) (\($0))" } ?? size.displayName
	}
}
