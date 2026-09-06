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
	func regionalWordmarkFallbackNamesTheActiveRegion() {
		#expect(
			L10n.string(
				HomeStrings.wordmarkFallback(region: .global),
				locale: Locale(identifier: "en")
			)
				== "ARKNIGHTS · GLOBAL"
		)
		#expect(
			L10n.string(
				HomeStrings.wordmarkFallback(region: .japan),
				locale: Locale(identifier: "en")
			)
				== "ARKNIGHTS · JAPAN"
		)
		#expect(
			L10n.string(
				HomeStrings.wordmarkFallback(region: .korea),
				locale: Locale(identifier: "en")
			)
				== "ARKNIGHTS · KOREA"
		)
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

		#expect(germanMessage == "Der Spieledienst hat eine ungültige Antwort zurückgegeben.")
		#expect(error.diagnosticDescription == "The game service returned an invalid response.")
	}

	@Test
	func publisherSupportCopyFollowsTheActiveRegion() {
		#expect(
			L10n.string(
				SettingsStrings.contactPublisherTitle(region: .global),
				locale: Locale(identifier: "en")
			) == "Contact Yostar…"
		)
		#expect(
			L10n.string(
				SettingsStrings.contactPublisherTitle(region: .china),
				locale: Locale(identifier: "en")
			) == "Contact Hypergryph…"
		)
		#expect(
			L10n.string(
				SettingsStrings.gameAccountIssuesDetail(region: .china),
				locale: Locale(identifier: "en")
			) == "Contact Hypergryph for account, payment, or game-service problems."
		)
		#expect(
			L10n.string(
				OnboardingStrings.communitySupport(region: .chinaBilibili),
				locale: Locale(identifier: "de")
			)
				== "Wende dich bei Problemen mit Konto, Zahlung oder Spieldienst stattdessen an den Hypergryph-Support."
		)
		#expect(
			L10n.string(
				OnboardingStrings.contactSupport(region: .global),
				locale: Locale(identifier: "de")
			) == "Yostar-Support kontaktieren…"
		)
		#expect(
			L10n.string(
				OnboardingStrings.contactSupport(region: .china),
				locale: Locale(identifier: "en")
			) == "Contact Hypergryph Support…"
		)
	}
}
