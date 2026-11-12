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
	let lifecycle: LauncherLifecycleStore
	let presetCatalog: PresetCatalogService
	let actions: any LauncherSettingsActions
	@State private var presentedGallery: PresetGalleryDestination?

	var body: some View {
		SettingsPage(
			title: "Appearance",
			subtitle: "Artwork, theme, appearance, and icons"
		) {
			SettingsPanel(title: "Artwork") {
				artworkRow
			}
			SettingsPanel(title: "Theme") {
				SettingsActionRow(
					title: "Dynamic Theme",
					detail:
						"The launcher accent and the generated Dock icons use the colors of the current artwork.",
					help:
						"Dynamic Theme: derives the launcher accent and the generated Dock icon pair from the selected artwork."
				) {
					SettingsToggle(
						"Dynamic Theme",
						isOn: $settings.usesDynamicTheme,
					)
				}
				SettingsHairline()
				SettingsActionRow(
					title: "Appearance",
					detail: "Settings, setup, and dialogs. Home keeps its own controls."
				) {
					AdaptiveSegmentedControl(
						selection: $settings.launcherAppearance,
						options: LauncherAppearance.allCases,
						systemImages: ["circle.lefthalf.filled", "sun.max", "moon"]
					) { appearance in
						Text(appearanceTitle(appearance))
					}
				}
				SettingsHairline()
				SettingsActionRow(
					title: "Home controls",
					detail:
						"The music, version, and status buttons, and the settings button. Automatic follows the artwork."
				) {
					AdaptiveSegmentedControl(
						selection: $settings.homeTheme,
						options: HomeTheme.allCases
					) { homeTheme in
						Text(themeTitle(homeTheme))
					}
				}
				SettingsHairline()
				SettingsActionRow(
					title: "Branding colors",
					detail:
						"Logo and backdrop in the top left corner. Automatic follows Home controls."
				) {
					AdaptiveSegmentedControl(
						selection: $settings.brandingTheme,
						options: HomeTheme.allCases
					) { brandingTheme in
						Text(themeTitle(brandingTheme))
					}
				}
			}
			SettingsPanel(title: "Home screen") {
				SettingsActionRow(
					title: "Branding",
					detail: "Shows the server logo and its backdrop in the top left corner."
				) {
					SettingsToggle(
						"Branding",
						isOn: $settings.showsBranding,
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
					)
				}
				SettingsHairline()
				SettingsActionRow(
					title: "Server time and reset countdown",
					detail: "Shows the server clock and the time until its next daily reset."
				) {
					SettingsToggle(
						"Server time and reset countdown",
						isOn: $settings.showsServerResetCountdown,
					)
				}
			}
			SettingsPanel(title: "Dock icons") {
				operatorRow
				SettingsHairline()
				customIconRow
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

	private func themeTitle(_ theme: HomeTheme) -> String {
		switch theme {
		case .automatic: "Automatic"
		case .dark: "Dark"
		case .light: "Light"
		}
	}

	private func appearanceTitle(_ appearance: LauncherAppearance) -> String {
		switch appearance {
		case .system: "System"
		case .light: "Light"
		case .dark: "Dark"
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
				tone: .neutral, presentation: .compact
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
				tone: .neutral,
				presentation: .compact
			) {
				presentedGallery = .operatorIcons
			}
			CapsuleActionButton(
				title: Self.useDefaultTitle,
				systemImage: "arrow.counterclockwise",
				tone: .neutral,
				presentation: .compact,
				action: customization.resetOperatorIcons
			)
		}
	}

	private var customIconRow: some View {
		SettingsActionRow(
			title: "Custom icons",
			detail:
				"Launcher and game Dock icons. Each new image or operator replaces the one before."
		) {
			GlassActionMenu(
				title: "Launcher",
				systemImage: "macwindow",
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
