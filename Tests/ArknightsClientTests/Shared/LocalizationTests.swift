// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

struct LocalizationTests {
	@Test
	func resolvesEnglishAndGermanFromTheCatalog() {
		#expect(L10n.string(HomeStrings.settings, locale: Locale(identifier: "en")) == "Settings")
		#expect(
			L10n.string(HomeStrings.settings, locale: Locale(identifier: "de"))
				== "Einstellungen"
		)
	}

	@Test
	func fallsBackToEnglishForUnsupportedLocales() {
		#expect(
			L10n.string(HomeStrings.settings, locale: Locale(identifier: "fr"))
				== "Settings"
		)
	}

	@Test
	func localizesInterpolatedValuesWithoutChangingTheirContents() {
		let progress = HomeStrings.downloadProgress(downloaded: "1.2 GB", total: "3.4 GB")
		let volume = AudioStrings.volumePercent(60)

		#expect(
			L10n.string(progress, locale: Locale(identifier: "de"))
				== "1.2 GB von 3.4 GB"
		)
		#expect(L10n.string(volume, locale: Locale(identifier: "de")) == "60 Prozent")
	}

	@Test
	func appliesLocaleSpecificPercentageFormatting() {
		let german = L10n.string(
			SettingsStrings.audioVolumePercent(60),
			locale: Locale(identifier: "de")
		)
		let english = L10n.string(
			SettingsStrings.audioVolumePercent(60),
			locale: Locale(identifier: "en")
		)

		#expect(german == "60 %")
		#expect(english == "60%")
	}

	@Test
	func keepsDiagnosticsEnglishWhileTheUserMessageCanBeLocalized() {
		let error = LauncherError.invalidResponse
		let germanMessage = L10n.string(
			LocalizedStringResource.Launcher.launcherErrorInvalidResponse,
			locale: Locale(identifier: "de")
		)

		#expect(germanMessage == "Der Yostar-Server hat eine ungültige Antwort zurückgegeben.")
		#expect(error.diagnosticDescription == "Yostar's server returned an invalid response.")
	}
}
