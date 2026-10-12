// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsCustomization
import ArknightsGameInstallation
import SwiftUI
import UniformTypeIdentifiers

private func isImageURL(_ url: URL) -> Bool {
	UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) == true
}

struct AppearanceSettingsPage: View {
	private static let useDefaultTitle = "Use Default"

	@Bindable var settings: LauncherPreferencesController
	let customization: CustomizationController
	package let lifecycle: LauncherLifecycleStore
	let presetCatalog: PresetCatalogService
	package let accentColor: Color
	let actions: any LauncherActions
	@State private var presentedGallery: PresetGalleryDestination?

	var body: some View {
		SettingsPage(
			title: "Appearance",
			subtitle: "Artwork, colors, and icons",
			accentColor: accentColor
		) {
			SettingsPanel(title: "Artwork", systemImage: "photo") {
				artworkRow
			}
			SettingsPanel(title: "Colors", systemImage: "paintpalette") {
				SettingsActionRow(
					title: "Match colors to the artwork",
					detail:
						"The launcher and the generated Dock icons borrow the artwork's colors.",
					help:
						"Dynamic Theme: derives the launcher accent, HUD tint, and generated Dock icon pair from the selected artwork."
				) {
					SettingsToggle(
						"Match colors to the artwork",
						isOn: $settings.usesDynamicTheme,
						accentColor: accentColor
					)
				}
			}
			SettingsPanel(title: "Dock icons", systemImage: "dock.rectangle") {
				operatorRow
				SettingsHairline()
				customIconRow
			}
			SettingsPanel(title: "Launcher shows", systemImage: "sparkles") {
				SettingsActionRow(
					title: "Branding",
					detail: "Shows the server logo and its backdrop in the top left corner."
				) {
					SettingsToggle(
						"Branding",
						isOn: $settings.showsBranding,
						accentColor: accentColor
					)
				}
				SettingsHairline()
				SettingsActionRow(
					title: "Game version",
					detail: "Shows the installed version and an update check above the Play button."
				) {
					SettingsToggle(
						"Game version",
						isOn: $settings.showsGameVersion,
						accentColor: accentColor
					)
				}
				SettingsHairline()
				SettingsActionRow(
					title: "Server time & reset countdown",
					detail: "Shows the server clock and the time until its next daily reset."
				) {
					SettingsToggle(
						"Server time & reset countdown",
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
			title: "Artwork",
			detail: "The picture behind the launcher. You can also drop an image here."
		) {
			CapsuleActionButton(
				title: "Presets…",
				systemImage: "photo.on.rectangle",
				tone: .accent(accentColor), presentation: .compact
			) {
				presentedGallery = .artwork
			}
			CapsuleActionButton(
				title: "Choose…", systemImage: "folder",
				tone: .neutral, presentation: .compact,
				action: customization.chooseCustomArtwork
			)
			CapsuleActionButton(
				title: Self.useDefaultTitle,
				systemImage: "arrow.counterclockwise",
				tone: .neutral,
				presentation: .compact,
				action: actions.resetArtwork
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
			title: "Operator",
			detail: "Pick one operator for the launcher and game icons in your Dock."
		) {
			CapsuleActionButton(
				title: "Choose Operator…",
				systemImage: "person.2.crop.square.stack",
				tone: .accent(accentColor),
				presentation: .compact
			) {
				presentedGallery = .operatorIcons
			}
			CapsuleActionButton(
				title: "Use Defaults",
				systemImage: "arrow.counterclockwise",
				tone: .neutral,
				presentation: .compact,
				action: customization.resetOperatorIcons
			)
		}
	}

	private var customIconRow: some View {
		SettingsActionRow(
			title: "Your own images",
			detail: "Use pictures from your Mac instead of the operator icons."
		) {
			GlassActionMenu(
				title: "Launcher",
				systemImage: "macwindow",
				accentColor: accentColor
			) {
				Button(
					"Choose Image…", systemImage: "folder",
					action: customization.chooseCustomAppIcon)
				Button(
					Self.useDefaultTitle,
					systemImage: "arrow.counterclockwise",
					action: customization.resetAppIcon)
			}
			.dropDestination(for: URL.self) { urls, _ in
				guard let url = urls.first, isImageURL(url) else { return false }
				customization.applyCustomAppIcon(from: url)
				return true
			}
			GlassActionMenu(
				title: "Game",
				systemImage: "gamecontroller",
				accentColor: accentColor
			) {
				Button(
					"Choose Image…", systemImage: "folder",
					action: customization.chooseCustomGameIcon)
				Button(
					Self.useDefaultTitle,
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
