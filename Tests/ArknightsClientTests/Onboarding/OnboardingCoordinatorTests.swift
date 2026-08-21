// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@MainActor
struct OnboardingCoordinatorTests {
	@Test
	func currentLauncherCanAdvanceAndResume() async {
		let (defaults, suiteName) = makeDefaults()
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let store = OnboardingProgressStore(defaults: defaults)
		let coordinator = OnboardingCoordinator(store: store)

		await coordinator.startIfNeeded(
			isDeveloperMode: false,
			isOnboardingPreview: false,
			gameIsInstalled: true,
			checkForUpdates: { .current },
			checkIntelTranslation: { .available }
		)
		#expect(coordinator.isPresented)
		#expect(coordinator.step == .welcome)

		coordinator.advance()
		coordinator.advance()
		#expect(coordinator.step == .game)

		let resumed = OnboardingCoordinator(store: store)
		await resumed.startIfNeeded(
			isDeveloperMode: false,
			isOnboardingPreview: false,
			gameIsInstalled: true,
			checkForUpdates: { .current },
			checkIntelTranslation: { .available }
		)
		resumed.advance()

		#expect(resumed.step == .game)
	}

	@Test
	func missingGameClampsResumeToInstallation() async {
		let (defaults, suiteName) = makeDefaults()
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let store = OnboardingProgressStore(defaults: defaults)
		store.save(step: .icons)
		let coordinator = OnboardingCoordinator(store: store)

		await coordinator.startIfNeeded(
			isDeveloperMode: false,
			isOnboardingPreview: false,
			gameIsInstalled: false,
			checkForUpdates: { .current },
			checkIntelTranslation: { .available }
		)
		coordinator.advance()

		#expect(coordinator.step == .installation)
	}

	@Test
	func availableUpdateBlocksSetupAndSkip() async {
		let (defaults, suiteName) = makeDefaults()
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let store = OnboardingProgressStore(defaults: defaults)
		let coordinator = OnboardingCoordinator(store: store)
		let release = LauncherRelease(
			tagName: "v0.5.0",
			htmlURL: URL(string: "https://example.com/release")!,
			body: nil,
			isDraft: false,
			isPrerelease: false
		)

		await coordinator.startIfNeeded(
			isDeveloperMode: false,
			isOnboardingPreview: false,
			gameIsInstalled: false,
			checkForUpdates: { .updateAvailable(release) },
			checkIntelTranslation: { .available }
		)
		coordinator.advance()
		coordinator.skip()

		#expect(coordinator.step == .welcome)
		#expect(coordinator.intelTranslationState == .waitingForLauncherCheck)
		#expect(coordinator.isPresented)
		#expect(store.needsOnboarding)
	}

	@Test
	func failedUpdateCheckAllowsSetupAndSkip() async {
		let (defaults, suiteName) = makeDefaults()
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let store = OnboardingProgressStore(defaults: defaults)
		let coordinator = OnboardingCoordinator(store: store)

		await coordinator.startIfNeeded(
			isDeveloperMode: false,
			isOnboardingPreview: false,
			gameIsInstalled: false,
			checkForUpdates: { .failed },
			checkIntelTranslation: { .available }
		)
		coordinator.advance()
		#expect(coordinator.step == .installation)

		coordinator.skip()
		#expect(!coordinator.isPresented)
		#expect(!store.needsOnboarding)
	}

	@Test
	func rosettaIsCheckedOnlyAfterTheLauncherCanContinue() async {
		let (defaults, suiteName) = makeDefaults()
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let coordinator = OnboardingCoordinator(
			store: OnboardingProgressStore(defaults: defaults)
		)
		var checks = 0

		await coordinator.startIfNeeded(
			isDeveloperMode: false,
			isOnboardingPreview: false,
			gameIsInstalled: false,
			checkForUpdates: { .current },
			checkIntelTranslation: {
				checks += 1
				return .rosettaMissing
			}
		)

		#expect(checks == 1)
		#expect(coordinator.intelTranslationState == .rosettaMissing)

		await coordinator.refreshIntelTranslationAvailability(
			checkIntelTranslation: { .available }
		)
		#expect(coordinator.intelTranslationState == .available)
	}

	private func makeDefaults() -> (UserDefaults, String) {
		let suiteName = "OnboardingCoordinatorTests.\(UUID().uuidString)"
		return (UserDefaults(suiteName: suiteName)!, suiteName)
	}
}
