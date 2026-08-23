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
			title: L10n.string(SettingsStrings.generalTitle),
			subtitle: L10n.string(SettingsStrings.generalSubtitle),
			accentColor: model.accentColor
		) {
			SettingsPanel(
				title: L10n.string(SettingsStrings.displayControls), systemImage: "display"
			) {
				SettingsActionRow(
					title: L10n.string(SettingsStrings.highResolution),
					detail: L10n.string(SettingsStrings.highResolutionDetail)
				) {
					Toggle(
						L10n.string(SettingsStrings.highResolution),
						isOn: $model.launchOptions.usesHighResolutionMode
					)
					.labelsHidden()
					.toggleStyle(.switch)
					.tint(model.accentColor)
					.disabled(!model.canModifyLaunchOptions)
				}
				SettingsHairline()
				SettingsActionRow(
					title: L10n.string(SettingsStrings.gameDisplaySettings),
					detail: L10n.string(SettingsStrings.gameDisplaySettingsDetail)
				) {
					Toggle(
						L10n.string(SettingsStrings.gameDisplaySettings),
						isOn: $model.launchOptions.usesGameSettings
					)
					.labelsHidden()
					.toggleStyle(.switch)
					.tint(model.accentColor)
					.disabled(!model.canModifyLaunchOptions)
				}
				SettingsHairline()
				SettingsActionRow(
					title: L10n.string(SettingsStrings.windowMode),
					detail: L10n.string(SettingsStrings.windowModeDetail)
				) {
					GlassMenuPicker(
						selection: $model.launchOptions.displayMode,
						options: GameDisplayMode.allCases.map {
							($0, L10n.string(SettingsStrings.displayMode($0)))
						},
						accentColor: model.accentColor,
						isDisabled: model.launchOptions.usesGameSettings
							|| !model.canModifyLaunchOptions
					)
				}
				SettingsHairline()
				SettingsActionRow(
					title: L10n.string(SettingsStrings.resolution),
					detail: L10n.string(SettingsStrings.resolutionDetail)
				) {
					GlassMenuPicker(
						selection: $model.launchOptions.resolution,
						options: GameResolution.allCases.map { ($0, $0.displayName) },
						accentColor: model.accentColor,
						isDisabled: model.launchOptions.usesGameSettings
							|| !model.canModifyLaunchOptions
					)
				}
			}

			SettingsPanel(title: L10n.string(SettingsStrings.launcher), systemImage: "sparkles") {
				SettingsActionRow(
					title: L10n.string(SettingsStrings.language),
					detail: L10n.string(SettingsStrings.languageDetail)
				) {
					GlassMenuPicker(
						selection: $model.appLanguage,
						options: AppLanguage.allCases.map {
							($0, L10n.string(SettingsStrings.appLanguage($0)))
						},
						accentColor: model.accentColor
					)
				}
				SettingsHairline()
				SettingsActionRow(
					title: L10n.string(SettingsStrings.showGameVersion),
					detail: L10n.string(SettingsStrings.showGameVersionDetail)
				) {
					Toggle(
						L10n.string(SettingsStrings.showGameVersion), isOn: $model.showsGameVersion
					)
					.labelsHidden()
					.toggleStyle(.switch)
					.tint(model.accentColor)
				}
				SettingsHairline()
				SettingsActionRow(
					title: L10n.string(SettingsStrings.serverTime),
					detail: L10n.string(SettingsStrings.serverTimeDetail)
				) {
					Toggle(
						L10n.string(SettingsStrings.serverTime),
						isOn: $model.showsServerResetCountdown
					)
					.labelsHidden()
					.toggleStyle(.switch)
					.tint(model.accentColor)
				}
				SettingsHairline()
				SettingsActionRow(
					title: L10n.string(SettingsStrings.metalHUD),
					detail: L10n.string(SettingsStrings.metalHUDDetail)
				) {
					Toggle(
						L10n.string(SettingsStrings.metalHUD),
						isOn: $model.launchOptions.usesMetalPerformanceHUD
					)
					.labelsHidden()
					.toggleStyle(.switch)
					.tint(model.accentColor)
					.disabled(!model.canModifyLaunchOptions)
				}
				SettingsHairline()
				SettingsActionRow(
					title: L10n.string(SettingsStrings.setupAssistant),
					detail: L10n.string(SettingsStrings.setupAssistantDetail)
				) {
					CapsuleActionButton(
						title: L10n.string(SettingsStrings.runAgain), systemImage: "wand.and.stars",
						tone: .accent(model.accentColor), presentation: .compact,
						action: restartOnboarding
					)
					.disabled(!model.canModifyLaunchOptions)
				}
			}

			SettingsPanel(
				title: L10n.string(SettingsStrings.personalization), systemImage: "paintbrush"
			) {
				SettingsActionRow(
					title: L10n.string(SettingsStrings.artwork),
					detail: L10n.string(SettingsStrings.artworkDetail)
				) {
					CapsuleActionButton(
						title: L10n.string(SettingsStrings.presets),
						systemImage: "photo.on.rectangle",
						tone: .accent(model.accentColor), presentation: .compact
					) {
						presentedGallery = .artwork
					}
					CapsuleActionButton(
						title: L10n.string(SettingsStrings.choose), systemImage: "folder",
						tone: .accent(model.accentColor), presentation: .compact,
						action: model.chooseCustomArtwork
					)
					CapsuleActionButton(
						L10n.string(SettingsStrings.useDefault),
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
					title: L10n.string(SettingsStrings.operatorIcons),
					detail: L10n.string(SettingsStrings.operatorIconsDetail)
				) {
					CapsuleActionButton(
						title: L10n.string(SettingsStrings.chooseOperator),
						systemImage: "person.2.crop.square.stack",
						tone: .accent(model.accentColor),
						presentation: .compact
					) {
						presentedGallery = .operatorIcons
					}
					CapsuleActionButton(
						L10n.string(SettingsStrings.useDefaults),
						systemImage: "arrow.counterclockwise",
						tone: .neutral,
						presentation: .compact,
						action: model.resetOperatorIcons
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
						accentColor: model.accentColor
					) {
						Button(
							L10n.string(SettingsStrings.chooseImage), systemImage: "folder",
							action: model.chooseCustomAppIcon)
						Button(
							L10n.string(SettingsStrings.useDefault),
							systemImage: "arrow.counterclockwise",
							action: model.resetAppIcon)
					}
					.dropDestination(for: URL.self) { urls, _ in
						guard let url = urls.first, isImageURL(url) else { return false }
						model.applyCustomAppIcon(from: url)
						return true
					}
					GlassActionMenu(
						title: L10n.string(SettingsStrings.game),
						systemImage: "gamecontroller",
						accentColor: model.accentColor
					) {
						Button(
							L10n.string(SettingsStrings.chooseImage), systemImage: "folder",
							action: model.chooseCustomGameIcon)
						Button(
							L10n.string(SettingsStrings.useDefault),
							systemImage: "arrow.counterclockwise",
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
					title: L10n.string(SettingsStrings.dynamicTheme),
					detail: L10n.string(SettingsStrings.dynamicThemeDetail)
				) {
					Toggle(L10n.string(SettingsStrings.dynamicTheme), isOn: $model.usesDynamicTheme)
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
