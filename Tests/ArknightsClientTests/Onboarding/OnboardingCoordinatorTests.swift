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
		#expect(coordinator.step == .display)

		let resumed = OnboardingCoordinator(store: store)
		await resumed.startIfNeeded(
			isDeveloperMode: false,
			isOnboardingPreview: false,
			gameIsInstalled: true,
			checkForUpdates: { .current },
			checkIntelTranslation: { .available }
		)
		resumed.advance()

		#expect(resumed.step == .display)
	}

	@Test
	func missingGameClampsResumeToRegion() async {
		let (defaults, suiteName) = makeDefaults()
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let store = OnboardingProgressStore(defaults: defaults)
		store.save(step: .look)
		let coordinator = OnboardingCoordinator(store: store)

		await coordinator.startIfNeeded(
			isDeveloperMode: false,
			isOnboardingPreview: false,
			gameIsInstalled: false,
			checkForUpdates: { .current },
			checkIntelTranslation: { .available }
		)
		coordinator.advance()

		#expect(coordinator.step == .region)
	}

	@Test
	func stepSavedByAnEarlierLauncherRestartsAtTheSystemCheck() async {
		let (defaults, suiteName) = makeDefaults()
		defer { defaults.removePersistentDomain(forName: suiteName) }
		defaults.set(5, forKey: "onboarding.currentStep")
		let coordinator = OnboardingCoordinator(store: OnboardingProgressStore(defaults: defaults))

		await coordinator.startIfNeeded(
			isDeveloperMode: false,
			isOnboardingPreview: false,
			gameIsInstalled: true,
			checkForUpdates: { .current },
			checkIntelTranslation: { .available }
		)
		#expect(coordinator.step == .welcome)

		coordinator.advance()
		#expect(coordinator.step == .region)
	}

	@Test(arguments: [
		("launcher update available", true),
		("launcher update check failed", false),
	])
	func launcherUpdateGateControlsSetupAndSkip(
		caseLabel: String,
		updateIsAvailable: Bool
	) async {
		let (defaults, suiteName) = makeDefaults()
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let store = OnboardingProgressStore(defaults: defaults)
		let coordinator = OnboardingCoordinator(store: store)
		await coordinator.startIfNeeded(
			isDeveloperMode: false,
			isOnboardingPreview: false,
			gameIsInstalled: false,
			checkForUpdates: {
				updateIsAvailable ? .updateAvailable("0.5.0") : .failed
			},
			checkIntelTranslation: { .available }
		)
		coordinator.advance()
		#expect(
			coordinator.step == (updateIsAvailable ? .welcome : .region),
			Comment(rawValue: caseLabel)
		)
		coordinator.skip()
		if updateIsAvailable {
			#expect(coordinator.step == .welcome, Comment(rawValue: caseLabel))
		} else {
			#expect(!coordinator.isPresented, Comment(rawValue: caseLabel))
			#expect(!store.needsOnboarding, Comment(rawValue: caseLabel))
		}

		#expect(
			coordinator.intelTranslationState
				== (updateIsAvailable ? .waitingForLauncherCheck : .available),
			Comment(rawValue: caseLabel))
		#expect(coordinator.isPresented == updateIsAvailable, Comment(rawValue: caseLabel))
		#expect(store.needsOnboarding == updateIsAvailable, Comment(rawValue: caseLabel))
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

	#if DEBUG
		@Test
		func developerPreviewCanBeToggledWithoutCompletingOnboarding() async {
			let (defaults, suiteName) = makeDefaults()
			defer { defaults.removePersistentDomain(forName: suiteName) }
			let store = OnboardingProgressStore(defaults: defaults)
			let coordinator = OnboardingCoordinator(store: store)

			await coordinator.startIfNeeded(
				isDeveloperMode: true,
				isOnboardingPreview: true,
				gameIsInstalled: true,
				checkForUpdates: { .current },
				checkIntelTranslation: { .available }
			)
			#expect(coordinator.isPresented)

			coordinator.dismissDeveloperPreview()

			#expect(!coordinator.isPresented)
			#expect(store.needsOnboarding)
		}
	#endif

	@Test
	func requiredSetupCannotBeSkippedUntilFinished() async {
		let (defaults, suiteName) = makeDefaults()
		defer { defaults.removePersistentDomain(forName: suiteName) }
		defaults.set(1, forKey: "onboarding.completedSchemaVersion")
		let store = OnboardingProgressStore(defaults: defaults)
		let coordinator = OnboardingCoordinator(store: store)

		await coordinator.startIfNeeded(
			isDeveloperMode: false,
			isOnboardingPreview: false,
			gameIsInstalled: true,
			checkForUpdates: { .current },
			checkIntelTranslation: { .available }
		)
		#expect(coordinator.requiredSchema == 2)

		coordinator.skip()
		#expect(coordinator.isPresented)
		#expect(store.needsOnboarding)

		coordinator.finish()
		#expect(!store.needsOnboarding)
		#expect(store.pendingRequiredSchema == nil)
	}

	@Test
	func restartedSetupStaysSkippable() async {
		let (defaults, suiteName) = makeDefaults()
		defer { defaults.removePersistentDomain(forName: suiteName) }
		defaults.set(1, forKey: "onboarding.completedSchemaVersion")
		let coordinator = OnboardingCoordinator(store: OnboardingProgressStore(defaults: defaults))

		await coordinator.restart(
			gameIsInstalled: true,
			checkForUpdates: { .current },
			checkIntelTranslation: { .available }
		)
		#expect(coordinator.requiredSchema == nil)

		coordinator.skip()
		#expect(!coordinator.isPresented)
	}

	@Test
	func setupFinishedBeforeTheQuestionsRunsAgain() {
		let (defaults, suiteName) = makeDefaults()
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let store = OnboardingProgressStore(defaults: defaults)

		defaults.set(1, forKey: "onboarding.completedSchemaVersion")
		#expect(store.needsOnboarding)

		store.complete()
		#expect(!store.needsOnboarding)
	}

	private func makeDefaults() -> (UserDefaults, String) {
		let suiteName = "OnboardingCoordinatorTests.\(UUID().uuidString)"
		return (UserDefaults(suiteName: suiteName)!, suiteName)
	}
}
