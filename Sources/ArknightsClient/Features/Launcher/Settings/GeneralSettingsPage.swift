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
			title: L10n.string(SettingsStrings.generalTitle),
			subtitle: L10n.string(SettingsStrings.generalSubtitle),
			accentColor: accentColor
		) {
			SettingsPanel(
				title: L10n.string(SettingsStrings.displayControls), systemImage: "display"
			) {
				SettingsActionRow(
					title: L10n.string(SettingsStrings.highResolution),
					detail: L10n.string(SettingsStrings.highResolutionDetail)
				) {
					SettingsToggle(
						L10n.string(SettingsStrings.highResolution),
						isOn: $settings.launchOptions.usesHighResolutionMode,
						accentColor: accentColor
					)
					.disabled(gameSession.isGameActive)
				}
				SettingsHairline()
				SettingsActionRow(
					title: L10n.string(SettingsStrings.gameDisplaySettings),
					detail: L10n.string(SettingsStrings.gameDisplaySettingsDetail)
				) {
					SettingsToggle(
						L10n.string(SettingsStrings.gameDisplaySettings),
						isOn: $settings.launchOptions.usesGameSettings,
						accentColor: accentColor
					)
					.disabled(gameSession.isGameActive)
				}
				SettingsHairline()
				SettingsActionRow(
					title: L10n.string(SettingsStrings.windowMode),
					detail: L10n.string(SettingsStrings.windowModeDetail)
				) {
					GlassMenuPicker(
						selection: $settings.launchOptions.displayMode,
						options: GameDisplayMode.allCases.map {
							($0, L10n.string(SettingsStrings.displayMode($0)))
						},
						accentColor: accentColor,
						isDisabled: settings.launchOptions.usesGameSettings
							|| gameSession.isGameActive
					)
				}
				SettingsHairline()
				SettingsActionRow(
					title: L10n.string(SettingsStrings.resolution),
					detail: L10n.string(SettingsStrings.resolutionDetail)
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

			SettingsPanel(title: L10n.string(SettingsStrings.launcher), systemImage: "sparkles") {
				SettingsActionRow(
					title: L10n.string(SettingsStrings.showGameVersion),
					detail: L10n.string(SettingsStrings.showGameVersionDetail)
				) {
					SettingsToggle(
						L10n.string(SettingsStrings.showGameVersion),
						isOn: $settings.showsGameVersion,
						accentColor: accentColor
					)
				}
				SettingsHairline()
				SettingsActionRow(
					title: L10n.string(SettingsStrings.serverTime),
					detail: L10n.string(SettingsStrings.serverTimeDetail)
				) {
					SettingsToggle(
						L10n.string(SettingsStrings.serverTime),
						isOn: $settings.showsServerResetCountdown,
						accentColor: accentColor
					)
				}
				SettingsHairline()
				SettingsActionRow(
					title: L10n.string(SettingsStrings.setupAssistant),
					detail: L10n.string(SettingsStrings.setupAssistantDetail)
				) {
					CapsuleActionButton(
						title: L10n.string(SettingsStrings.runAgain), systemImage: "wand.and.stars",
						tone: .accent(accentColor), presentation: .compact,
						action: restartOnboarding
					)
					.disabled(gameSession.isGameActive)
				}
			}

			SettingsPanel(
				title: L10n.string(SettingsStrings.personalization), systemImage: "paintbrush"
			) {
				SettingsActionRow(
					title: L10n.string(SettingsStrings.language),
					detail: L10n.string(SettingsStrings.languageDetail)
				) {
					GlassMenuPicker(
						selection: $settings.appLanguage,
						options: AppLanguage.allCases.map {
							($0, L10n.string(SettingsStrings.appLanguage($0)))
						},
						accentColor: accentColor
					)
				}
				SettingsHairline()
				SettingsActionRow(
					title: L10n.string(SettingsStrings.artwork),
					detail: L10n.string(SettingsStrings.artworkDetail)
				) {
					CapsuleActionButton(
						title: L10n.string(SettingsStrings.presets),
						systemImage: "photo.on.rectangle",
						tone: .accent(accentColor), presentation: .compact
					) {
						presentedGallery = .artwork
					}
					CapsuleActionButton(
						title: L10n.string(SettingsStrings.choose), systemImage: "folder",
						tone: .accent(accentColor), presentation: .compact,
						action: customization.chooseCustomArtwork
					)
					CapsuleActionButton(
						title: L10n.string(SettingsStrings.useDefault),
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
					title: L10n.string(SettingsStrings.operatorIcons),
					detail: L10n.string(SettingsStrings.operatorIconsDetail)
				) {
					CapsuleActionButton(
						title: L10n.string(SettingsStrings.chooseOperator),
						systemImage: "person.2.crop.square.stack",
						tone: .accent(accentColor),
						presentation: .compact
					) {
						presentedGallery = .operatorIcons
					}
					CapsuleActionButton(
						title: L10n.string(SettingsStrings.useDefaults),
						systemImage: "arrow.counterclockwise",
						tone: .neutral,
						presentation: .compact,
						action: customization.resetOperatorIcons
					)
				}
				SettingsHairline()
				SettingsActionRow(
					title: L10n.string(SettingsStrings.customIconOverrides),
					detail: L10n.string(SettingsStrings.customIconOverridesDetail)
				) {
					GlassActionMenu(
						title: L10n.string(SettingsStrings.launcher),
						systemImage: "macwindow",
						accentColor: accentColor
					) {
						Button(
							L10n.string(SettingsStrings.chooseImage), systemImage: "folder",
							action: customization.chooseCustomAppIcon)
						Button(
							L10n.string(SettingsStrings.useDefault),
							systemImage: "arrow.counterclockwise",
							action: customization.resetAppIcon)
					}
					.dropDestination(for: URL.self) { urls, _ in
						guard let url = urls.first, isImageURL(url) else { return false }
						customization.applyCustomAppIcon(from: url)
						return true
					}
					GlassActionMenu(
						title: L10n.string(SettingsStrings.game),
						systemImage: "gamecontroller",
						accentColor: accentColor
					) {
						Button(
							L10n.string(SettingsStrings.chooseImage), systemImage: "folder",
							action: customization.chooseCustomGameIcon)
						Button(
							L10n.string(SettingsStrings.useDefault),
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
					title: L10n.string(SettingsStrings.dynamicTheme),
					detail: L10n.string(SettingsStrings.dynamicThemeDetail)
				) {
					SettingsToggle(
						L10n.string(SettingsStrings.dynamicTheme),
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
