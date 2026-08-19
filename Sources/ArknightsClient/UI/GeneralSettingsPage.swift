// SPDX-License-Identifier: MPL-2.0

import SwiftUI
import UniformTypeIdentifiers

private func isImageURL(_ url: URL) -> Bool {
	UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) == true
}

struct GeneralSettingsPage: View {
	@Bindable var model: LauncherViewModel
	@State private var presentedGalleryTab: PresetGalleryTab?

	var body: some View {
		SettingsPage(
			title: "General", subtitle: "Display and personalization",
			accentColor: model.accentColor
		) {
			SettingsPanel(title: "Display & Controls", systemImage: "display") {
				LabeledContent("High-resolution mode") {
					Toggle(
						"High-resolution mode",
						isOn: $model.launchOptions.usesHighResolutionMode
					)
					.labelsHidden()
					.toggleStyle(.switch)
					.tint(model.accentColor)
				}
				.help("Use the display's full pixel density without enlarging the game window")
				SettingsHairline()
				LabeledContent("Use in-game display settings") {
					Toggle(
						"Use in-game display settings",
						isOn: $model.launchOptions.usesGameSettings
					)
					.labelsHidden()
					.toggleStyle(.switch)
					.tint(model.accentColor)
				}
				.help("Lets changes made inside Arknights persist between launches")
				SettingsHairline()
				LabeledContent("Window Mode") {
					GlassMenuPicker(
						selection: $model.launchOptions.displayMode,
						options: GameDisplayMode.allCases.map { ($0, $0.displayName) },
						accentColor: model.accentColor,
						isDisabled: model.launchOptions.usesGameSettings
					)
				}
				.help("Overrides the game the next time it starts")
				SettingsHairline()
				LabeledContent("Resolution") {
					GlassMenuPicker(
						selection: $model.launchOptions.resolution,
						options: GameResolution.allCases.map { ($0, $0.displayName) },
						accentColor: model.accentColor,
						isDisabled: model.launchOptions.usesGameSettings
					)
				}
				.help("Overrides the game the next time it starts")
				SettingsHairline()
				LabeledContent("Precise Touchpad Scrolling") {
					Toggle(
						"Precise Touchpad Scrolling",
						isOn: $model.launchOptions.usesPreciseScrolling
					)
					.labelsHidden()
					.toggleStyle(.switch)
					.tint(model.accentColor)
				}
				.help("Restores horizontal panning, but vertical scrolling becomes very fast")
			}

			SettingsPanel(title: "Launcher", systemImage: "sparkles") {
				LabeledContent("Show Game Version") {
					Toggle("Show Game Version", isOn: $model.showsGameVersion)
						.labelsHidden()
						.toggleStyle(.switch)
						.tint(model.accentColor)
				}
				.help("Shows the installed Arknights version next to the region indicator")
				SettingsHairline()
				LabeledContent("Server Time & Reset Countdown") {
					Toggle(
						"Server Time & Reset Countdown",
						isOn: $model.showsServerResetCountdown
					)
					.labelsHidden()
					.toggleStyle(.switch)
					.tint(model.accentColor)
				}
				.help("Shows time until the daily server reset next to the version number")
				SettingsHairline()
				LabeledContent("Metal Performance HUD") {
					Toggle(
						"Metal Performance HUD",
						isOn: $model.launchOptions.usesMetalPerformanceHUD
					)
					.labelsHidden()
					.toggleStyle(.switch)
					.tint(model.accentColor)
				}
				.help("Shows Apple's native FPS and GPU overlay the next time the game starts")
			}

			SettingsPanel(title: "Personalization", systemImage: "paintbrush") {
				SettingsActionRow(
					title: "Artwork",
					detail: "Background shown behind the launcher controls."
				) {
					Button("Presets…") { presentedGalleryTab = .wallpapers }
					Button("Choose…", action: model.chooseCustomArtwork)
					Button("Use Default", action: model.resetArtwork)
				}
				.dropDestination(for: URL.self) { urls, _ in
					guard let url = urls.first, isImageURL(url) else { return false }
					model.applyCustomArtwork(from: url)
					return true
				}
				SettingsHairline()
				SettingsActionRow(
					title: "App Icon",
					detail: "Dock and Finder icon for the launcher."
				) {
					Button("Presets…") { presentedGalleryTab = .avatars }
					Button("Choose…", action: model.chooseCustomAppIcon)
					Button("Use Default", action: model.resetAppIcon)
				}
				.dropDestination(for: URL.self) { urls, _ in
					guard let url = urls.first, isImageURL(url) else { return false }
					model.applyCustomAppIcon(from: url)
					return true
				}
				SettingsHairline()
				LabeledContent("Dynamic Theme") {
					Toggle("Dynamic Theme", isOn: $model.usesDynamicTheme)
						.labelsHidden()
						.toggleStyle(.switch)
						.tint(model.accentColor)
				}
				.help("Harmonizes launcher accents and the app icon with the active artwork")
			}
		}
		.sheet(item: $presentedGalleryTab) { tab in
			PresetGalleryView(model: model, initialTab: .constant(tab))
		}
	}
}
