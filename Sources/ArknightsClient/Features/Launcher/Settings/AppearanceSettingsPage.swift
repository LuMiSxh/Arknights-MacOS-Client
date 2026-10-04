// SPDX-License-Identifier: MPL-2.0

import SwiftUI
import UniformTypeIdentifiers

private func isImageURL(_ url: URL) -> Bool {
	UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) == true
}

struct AppearanceSettingsPage: View {
	@Bindable var settings: LauncherPreferencesController
	let customization: CustomizationController
	let lifecycle: LauncherLifecycleStore
	let presetCatalog: PresetCatalogService
	let accentColor: Color
	let resetArtwork: () -> Void
	@State private var presentedGallery: PresetGalleryDestination?

	var body: some View {
		SettingsPage(
			title: SettingsStrings.appearanceTitle,
			subtitle: SettingsStrings.appearanceSubtitle,
			accentColor: accentColor
		) {
			SettingsPanel(title: SettingsStrings.artworkPanel, systemImage: "photo") {
				artworkRow
			}
			SettingsPanel(title: SettingsStrings.colorsPanel, systemImage: "paintpalette") {
				SettingsActionRow(
					title: SettingsStrings.dynamicTheme,
					detail: SettingsStrings.dynamicThemeDetail,
					help: SettingsStrings.dynamicThemeHelp
				) {
					SettingsToggle(
						SettingsStrings.dynamicTheme,
						isOn: $settings.usesDynamicTheme,
						accentColor: accentColor
					)
				}
			}
			SettingsPanel(title: SettingsStrings.dockIconsPanel, systemImage: "dock.rectangle") {
				operatorRow
				SettingsHairline()
				customIconRow
			}
			SettingsPanel(title: SettingsStrings.launcherShowsPanel, systemImage: "sparkles") {
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

	private var artworkRow: some View {
		SettingsActionRow(
			title: SettingsStrings.artworkPanel,
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
				tone: .neutral, presentation: .compact,
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
	}

	private var operatorRow: some View {
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
	}

	private var customIconRow: some View {
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
	}
}
