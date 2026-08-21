// SPDX-License-Identifier: MPL-2.0

import SwiftUI
import UniformTypeIdentifiers

private func isImageURL(_ url: URL) -> Bool {
	UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) == true
}

struct GeneralSettingsPage: View {
	@Bindable var model: LauncherViewModel
	let restartOnboarding: () -> Void
	@State private var presentedGallery: PresetGalleryDestination?

	var body: some View {
		SettingsPage(
			title: "General", subtitle: "Display and personalization",
			accentColor: model.accentColor
		) {
			SettingsPanel(title: "Display & Controls", systemImage: "display") {
				SettingsActionRow(
					title: "High-Resolution Mode",
					detail:
						"Uses the display's full pixel density without enlarging the game window."
				) {
					Toggle(
						"High-Resolution Mode",
						isOn: $model.launchOptions.usesHighResolutionMode
					)
					.labelsHidden()
					.toggleStyle(.switch)
					.tint(model.accentColor)
				}
				SettingsHairline()
				SettingsActionRow(
					title: "Use In-Game Display Settings",
					detail: "Lets changes made inside Arknights persist between launches."
				) {
					Toggle(
						"Use In-Game Display Settings",
						isOn: $model.launchOptions.usesGameSettings
					)
					.labelsHidden()
					.toggleStyle(.switch)
					.tint(model.accentColor)
				}
				SettingsHairline()
				SettingsActionRow(
					title: "Window Mode",
					detail: "Overrides the game window style the next time it starts."
				) {
					GlassMenuPicker(
						selection: $model.launchOptions.displayMode,
						options: GameDisplayMode.allCases.map { ($0, $0.displayName) },
						accentColor: model.accentColor,
						isDisabled: model.launchOptions.usesGameSettings
					)
				}
				SettingsHairline()
				SettingsActionRow(
					title: "Resolution",
					detail: "Overrides the game resolution the next time it starts."
				) {
					GlassMenuPicker(
						selection: $model.launchOptions.resolution,
						options: GameResolution.allCases.map { ($0, $0.displayName) },
						accentColor: model.accentColor,
						isDisabled: model.launchOptions.usesGameSettings
					)
				}
			}

			SettingsPanel(title: "Launcher", systemImage: "sparkles") {
				SettingsActionRow(
					title: "Show Game Version",
					detail:
						"Shows the installed Arknights version and a manual update check above the Play controls."
				) {
					Toggle("Show Game Version", isOn: $model.showsGameVersion)
						.labelsHidden()
						.toggleStyle(.switch)
						.tint(model.accentColor)
				}
				SettingsHairline()
				SettingsActionRow(
					title: "Server Time & Reset Countdown",
					detail: "Shows the active server time and time until its next daily reset."
				) {
					Toggle(
						"Server Time & Reset Countdown",
						isOn: $model.showsServerResetCountdown
					)
					.labelsHidden()
					.toggleStyle(.switch)
					.tint(model.accentColor)
				}
				SettingsHairline()
				SettingsActionRow(
					title: "Metal Performance HUD",
					detail: "Shows Apple's native FPS and GPU overlay during the next game launch."
				) {
					Toggle(
						"Metal Performance HUD",
						isOn: $model.launchOptions.usesMetalPerformanceHUD
					)
					.labelsHidden()
					.toggleStyle(.switch)
					.tint(model.accentColor)
				}
				SettingsHairline()
				SettingsActionRow(
					title: "Setup Assistant",
					detail: "Run the guided region, display, and personalization setup again."
				) {
					CapsuleActionButton(
						title: "Run Again…", systemImage: "wand.and.stars",
						tone: .accent(model.accentColor), presentation: .compact,
						action: restartOnboarding
					)
				}
			}

			SettingsPanel(title: "Personalization", systemImage: "paintbrush") {
				SettingsActionRow(
					title: "Artwork",
					detail: "Background shown behind the launcher controls."
				) {
					CapsuleActionButton(
						title: "Presets…", systemImage: "photo.on.rectangle",
						tone: .accent(model.accentColor), presentation: .compact
					) {
						presentedGallery = .artwork
					}
					CapsuleActionButton(
						title: "Choose…", systemImage: "folder",
						tone: .accent(model.accentColor), presentation: .compact,
						action: model.chooseCustomArtwork
					)
					CapsuleActionButton(
						"Use Default",
						systemImage: "arrow.counterclockwise",
						tone: .neutral,
						presentation: .compact,
						action: model.resetArtwork
					)
				}
				.dropDestination(for: URL.self) { urls, _ in
					guard let url = urls.first, isImageURL(url) else { return false }
					model.applyCustomArtwork(from: url)
					return true
				}
				SettingsHairline()
				SettingsActionRow(
					title: "Operator Icons",
					detail:
						"Use one operator for the Launcher and for a Game icon in the original Arknights style."
				) {
					CapsuleActionButton(
						title: "Choose Operator…",
						systemImage: "person.2.crop.square.stack",
						tone: .accent(model.accentColor),
						presentation: .compact
					) {
						presentedGallery = .operatorIcons
					}
					CapsuleActionButton(
						"Use Defaults",
						systemImage: "arrow.counterclockwise",
						tone: .neutral,
						presentation: .compact,
						action: model.resetOperatorIcons
					)
				}
				SettingsHairline()
				SettingsActionRow(
					title: "Custom Icon Overrides",
					detail:
						"Use separate local images instead of the generated operator pair."
				) {
					GlassActionMenu(
						title: "Launcher",
						systemImage: "macwindow",
						accentColor: model.accentColor
					) {
						Button(
							"Choose Image…", systemImage: "folder",
							action: model.chooseCustomAppIcon)
						Button(
							"Use Default", systemImage: "arrow.counterclockwise",
							action: model.resetAppIcon)
					}
					.dropDestination(for: URL.self) { urls, _ in
						guard let url = urls.first, isImageURL(url) else { return false }
						model.applyCustomAppIcon(from: url)
						return true
					}
					GlassActionMenu(
						title: "Game",
						systemImage: "gamecontroller",
						accentColor: model.accentColor
					) {
						Button(
							"Choose Image…", systemImage: "folder",
							action: model.chooseCustomGameIcon)
						Button(
							"Use Default", systemImage: "arrow.counterclockwise",
							action: model.resetGameIcon)
					}
					.dropDestination(for: URL.self) { urls, _ in
						guard let url = urls.first, isImageURL(url) else { return false }
						model.applyCustomGameIcon(from: url)
						return true
					}
				}
				SettingsHairline()
				SettingsActionRow(
					title: "Dynamic Theme",
					detail:
						"Automatically changes the launcher colors and generated operator icon pair to match the selected background."
				) {
					Toggle("Dynamic Theme", isOn: $model.usesDynamicTheme)
						.labelsHidden()
						.toggleStyle(.switch)
						.tint(model.accentColor)
				}
			}
		}
		.sheet(item: $presentedGallery) { destination in
			PresetGalleryView(model: model, destination: destination)
		}
	}
}
