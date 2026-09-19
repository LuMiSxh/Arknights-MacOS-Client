// SPDX-License-Identifier: MPL-2.0

import SwiftUI
import UniformTypeIdentifiers

private func isImageURL(_ url: URL) -> Bool {
	UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) == true
}

struct GeneralSettingsPage: View {
	@Bindable var settings: LauncherPreferencesController
	let customization: CustomizationController
	let gameSession: GameSessionController
	let lifecycle: LauncherLifecycleStore
	let presetCatalog: PresetCatalogService
	let accentColor: Color
	let resetArtwork: () -> Void
	let restartOnboarding: () -> Void
	@State private var presentedGallery: PresetGalleryDestination?

	var body: some View {
		SettingsPage(
			title: SettingsStrings.generalTitle,
			subtitle: SettingsStrings.generalSubtitle,
			accentColor: accentColor
		) {
			SettingsPanel(
				title: SettingsStrings.displayControls, systemImage: "display"
			) {
				SettingsActionRow(
					title: SettingsStrings.highResolution,
					detail: SettingsStrings.highResolutionDetail
				) {
					SettingsToggle(
						SettingsStrings.highResolution,
						isOn: $settings.launchOptions.usesHighResolutionMode,
						accentColor: accentColor
					)
					.disabled(
						gameSession.isGameActive
							|| lifecycle.activity == .maintaining(.migratingStorage)
					)
				}
				SettingsHairline()
				SettingsActionRow(
					title: SettingsStrings.gameDisplaySettings,
					detail: SettingsStrings.gameDisplaySettingsDetail
				) {
					SettingsToggle(
						SettingsStrings.gameDisplaySettings,
						isOn: $settings.launchOptions.usesGameSettings,
						accentColor: accentColor
					)
					.disabled(gameSession.isGameActive)
				}
				SettingsHairline()
				SettingsActionRow(
					title: SettingsStrings.windowMode,
					detail: SettingsStrings.windowModeDetail
				) {
					GlassMenuPicker(
						selection: $settings.launchOptions.displayMode,
						options: GameDisplayMode.allCases.map {
							($0, SettingsStrings.displayMode($0))
						},
						accentColor: accentColor,
						isDisabled: settings.launchOptions.usesGameSettings
							|| gameSession.isGameActive
					)
				}
				SettingsHairline()
				SettingsActionRow(
					title: SettingsStrings.resolution,
					detail: SettingsStrings.resolutionDetail
				) {
					GlassMenuPicker(
						selection: $settings.launchOptions.resolution,
						options: GameResolution.allCases.map { ($0, $0.displayName) },
						accentColor: accentColor,
						isDisabled: settings.launchOptions.usesGameSettings
							|| gameSession.isGameActive
					)
				}
			}

			SettingsPanel(title: SettingsStrings.launcher, systemImage: "sparkles") {
				SettingsActionRow(
					title: SettingsStrings.showGameVersion,
					detail: SettingsStrings.showGameVersionDetail
				) {
					SettingsToggle(
						SettingsStrings.showGameVersion,
						isOn: $settings.showsGameVersion,
						accentColor: accentColor
					)
				}
				SettingsHairline()
				SettingsActionRow(
					title: SettingsStrings.serverTime,
					detail: SettingsStrings.serverTimeDetail
				) {
					SettingsToggle(
						SettingsStrings.serverTime,
						isOn: $settings.showsServerResetCountdown,
						accentColor: accentColor
					)
				}
				SettingsHairline()
				SettingsActionRow(
					title: SettingsStrings.setupAssistant,
					detail: SettingsStrings.setupAssistantDetail
				) {
					CapsuleActionButton(
						title: SettingsStrings.runAgain, systemImage: "wand.and.stars",
						tone: .accent(accentColor), presentation: .compact,
						action: restartOnboarding
					)
					.disabled(gameSession.isGameActive)
				}
			}

			SettingsPanel(
				title: SettingsStrings.personalization, systemImage: "paintbrush"
			) {
				SettingsActionRow(
					title: SettingsStrings.artwork,
					detail: SettingsStrings.artworkDetail
				) {
					CapsuleActionButton(
						title: SettingsStrings.presets,
						systemImage: "photo.on.rectangle",
						tone: .accent(accentColor), presentation: .compact
					) {
						presentedGallery = .artwork
					}
					CapsuleActionButton(
						title: SettingsStrings.choose, systemImage: "folder",
						tone: .accent(accentColor), presentation: .compact,
						action: customization.chooseCustomArtwork
					)
					CapsuleActionButton(
						title: SettingsStrings.useDefault,
						systemImage: "arrow.counterclockwise",
						tone: .neutral,
						presentation: .compact,
						action: resetArtwork
					)
				}
				.dropDestination(for: URL.self) { urls, _ in
					guard let url = urls.first, isImageURL(url) else { return false }
					customization.applyCustomArtwork(from: url)
					return true
				}
				SettingsHairline()
				SettingsActionRow(
					title: SettingsStrings.operatorIcons,
					detail: SettingsStrings.operatorIconsDetail
				) {
					CapsuleActionButton(
						title: SettingsStrings.chooseOperator,
						systemImage: "person.2.crop.square.stack",
						tone: .accent(accentColor),
						presentation: .compact
					) {
						presentedGallery = .operatorIcons
					}
					CapsuleActionButton(
						title: SettingsStrings.useDefaults,
						systemImage: "arrow.counterclockwise",
						tone: .neutral,
						presentation: .compact,
						action: customization.resetOperatorIcons
					)
				}
				SettingsHairline()
				SettingsActionRow(
					title: SettingsStrings.customIconOverrides,
					detail: SettingsStrings.customIconOverridesDetail
				) {
					GlassActionMenu(
						title: SettingsStrings.launcher,
						systemImage: "macwindow",
						accentColor: accentColor
					) {
						Button(
							SettingsStrings.chooseImage, systemImage: "folder",
							action: customization.chooseCustomAppIcon)
						Button(
							SettingsStrings.useDefault,
							systemImage: "arrow.counterclockwise",
							action: customization.resetAppIcon)
					}
					.dropDestination(for: URL.self) { urls, _ in
						guard let url = urls.first, isImageURL(url) else { return false }
						customization.applyCustomAppIcon(from: url)
						return true
					}
					GlassActionMenu(
						title: SettingsStrings.game,
						systemImage: "gamecontroller",
						accentColor: accentColor
					) {
						Button(
							SettingsStrings.chooseImage, systemImage: "folder",
							action: customization.chooseCustomGameIcon)
						Button(
							SettingsStrings.useDefault,
							systemImage: "arrow.counterclockwise",
							action: customization.resetGameIcon)
					}
					.dropDestination(for: URL.self) { urls, _ in
						guard let url = urls.first, isImageURL(url) else { return false }
						customization.applyCustomGameIcon(from: url)
						return true
					}
				}
				SettingsHairline()
				SettingsActionRow(
					title: SettingsStrings.dynamicTheme,
					detail: SettingsStrings.dynamicThemeDetail
				) {
					SettingsToggle(
						SettingsStrings.dynamicTheme,
						isOn: $settings.usesDynamicTheme,
						accentColor: accentColor
					)
				}
			}
		}
		.sheet(item: $presentedGallery) { destination in
			PresetGalleryView(
				catalog: presetCatalog,
				customization: customization,
				lifecycle: lifecycle,
				destination: destination
			)
		}
	}
}
