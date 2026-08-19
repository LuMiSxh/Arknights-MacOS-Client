// SPDX-License-Identifier: MPL-2.0

import SwiftUI
import UniformTypeIdentifiers

private func isImageURL(_ url: URL) -> Bool {
	UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) == true
}

struct GeneralSettingsPage: View {
	@Bindable var model: LauncherViewModel

	var body: some View {
		SettingsPage(title: "General", subtitle: "Display and personalization") {
			SettingsPanel(title: "Display", systemImage: "rectangle.on.rectangle") {
				LabeledContent("High-resolution mode") {
					Toggle(
						"High-resolution mode",
						isOn: $model.launchOptions.usesHighResolutionMode
					)
					.labelsHidden()
					.toggleStyle(.switch)
					.tint(SettingsVisuals.cyan)
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
					.tint(SettingsVisuals.cyan)
				}
				.help("Lets changes made inside Arknights persist between launches")
				SettingsHairline()
				LabeledContent("Window Mode") {
					GlassMenuPicker(
						selection: $model.launchOptions.displayMode,
						options: GameDisplayMode.allCases.map { ($0, $0.displayName) },
						isDisabled: model.launchOptions.usesGameSettings
					)
				}
				.help("Overrides the game the next time it starts")
				SettingsHairline()
				LabeledContent("Resolution") {
					GlassMenuPicker(
						selection: $model.launchOptions.resolution,
						options: GameResolution.allCases.map { ($0, $0.displayName) },
						isDisabled: model.launchOptions.usesGameSettings
					)
				}
				.help("Overrides the game the next time it starts")
			}

			SettingsPanel(title: "Input", systemImage: "mouse") {
				LabeledContent("Precise Touchpad Scrolling") {
					Toggle(
						"Precise Touchpad Scrolling",
						isOn: $model.launchOptions.usesPreciseScrolling
					)
					.labelsHidden()
					.toggleStyle(.switch)
					.tint(SettingsVisuals.cyan)
				}
				.help("Restores horizontal panning, but vertical scrolling becomes very fast")
			}

			SettingsPanel(title: "Launcher", systemImage: "sparkles") {
				LabeledContent("Show Game Version") {
					Toggle("Show Game Version", isOn: $model.showsGameVersion)
						.labelsHidden()
						.toggleStyle(.switch)
						.tint(SettingsVisuals.cyan)
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
					.tint(SettingsVisuals.cyan)
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
					.tint(SettingsVisuals.cyan)
				}
				.help("Shows Apple's native FPS and GPU overlay the next time the game starts")
			}

			SettingsPanel(title: "Music", systemImage: "music.note") {
				LabeledContent("Play Background Music") {
					Toggle(
						"Play Background Music",
						isOn: $model.playsLauncherMusic
					)
					.labelsHidden()
					.toggleStyle(.switch)
					.tint(SettingsVisuals.cyan)
				}
				.help("Plays music while the launcher is open and the game is not running")

				if model.playsLauncherMusic {
					SettingsHairline()
					SettingsActionRow(
						title: "Music URL",
						detail: "YouTube video or playlist link."
					) {
						TextField(
							"https://www.youtube.com/playlist?...",
							text: $model.launcherMusicURL
						)
						.textFieldStyle(.roundedBorder)
						.frame(width: 250)
					}
					SettingsHairline()
					LabeledContent("Volume") {
						HStack(spacing: 8) {
							Image(systemName: "speaker.fill")
								.font(.caption)
								.foregroundStyle(.secondary)
							Slider(value: $model.launcherMusicVolume, in: 0...1, step: 0.05)
								.frame(width: 140)
							Image(systemName: "speaker.wave.3.fill")
								.font(.caption)
								.foregroundStyle(.secondary)
							Text("\(Int(model.launcherMusicVolume * 100))%")
								.font(.caption.monospacedDigit())
								.foregroundStyle(.secondary)
								.frame(width: 36, alignment: .trailing)
						}
					}
					SettingsHairline()
					LabeledContent("Show Currently Playing") {
						Toggle(
							"Show Currently Playing",
							isOn: $model.showsPlayingMusic
						)
						.labelsHidden()
						.toggleStyle(.switch)
						.tint(SettingsVisuals.cyan)
					}
					.help("Shows the title of the current track next to the version indicator")
				}
			}

			SettingsPanel(title: "Personalization", systemImage: "paintbrush") {
				SettingsActionRow(
					title: "Artwork",
					detail: "Background shown behind the launcher controls."
				) {
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
					Button("Choose…", action: model.chooseCustomAppIcon)
					Button("Use Default", action: model.resetAppIcon)
				}
				.dropDestination(for: URL.self) { urls, _ in
					guard let url = urls.first, isImageURL(url) else { return false }
					model.applyCustomAppIcon(from: url)
					return true
				}
			}
		}
	}
}
