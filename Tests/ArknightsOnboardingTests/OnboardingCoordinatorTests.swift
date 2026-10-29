// SPDX-License-Identifier: MPL-2.0

import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsOnboarding

@MainActor
struct OnboardingCoordinatorTests {
	@Test
	func currentLauncherCanAdvanceAndResume() async {
		let (defaults, suiteName) = makeIsolatedDefaults("OnboardingCoordinatorTests")
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

		store.save(step: .look)
		let withoutGame = OnboardingCoordinator(store: store)
		await withoutGame.startIfNeeded(
			isDeveloperMode: false,
			isOnboardingPreview: false,
			gameIsInstalled: false,
			checkForUpdates: { .current },
			checkIntelTranslation: { .available }
		)
		withoutGame.advance()
		#expect(withoutGame.step == .region)

		defaults.set(5, forKey: "onboarding.currentStep")
		let fromEarlierLauncher = OnboardingCoordinator(
			store: OnboardingProgressStore(defaults: defaults))
		await fromEarlierLauncher.startIfNeeded(
			isDeveloperMode: false,
			isOnboardingPreview: false,
			gameIsInstalled: true,
			checkForUpdates: { .current },
			checkIntelTranslation: { .available }
		)
		#expect(fromEarlierLauncher.step == .welcome)
		fromEarlierLauncher.advance()
		#expect(fromEarlierLauncher.step == .region)
	}

	@Test(arguments: [
		("launcher update available", true),
		("launcher update check failed", false),
	])
	func launcherUpdateGateControlsSetupAndSkip(
		caseLabel: String,
		updateIsAvailable: Bool
	) async {
		let (defaults, suiteName) = makeIsolatedDefaults("OnboardingCoordinatorTests")
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let store = OnboardingProgressStore(defaults: defaults)
		let coordinator = OnboardingCoordinator(store: store)
		var intelChecks = 0
		await coordinator.startIfNeeded(
			isDeveloperMode: false,
			isOnboardingPreview: false,
			gameIsInstalled: false,
			checkForUpdates: {
				updateIsAvailable ? .updateAvailable("0.5.0") : .failed
			},
			checkIntelTranslation: {
				intelChecks += 1
				return .available
			}
		)
		#expect(intelChecks == (updateIsAvailable ? 0 : 1), Comment(rawValue: caseLabel))
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
	func requiredSetupCannotBeSkippedUntilFinished() async {
		let (defaults, suiteName) = makeIsolatedDefaults("OnboardingCoordinatorTests")
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
		#expect(coordinator.requiredSchema == 3)

		coordinator.skip()
		#expect(coordinator.isPresented)
		#expect(store.needsOnboarding)

		coordinator.finish()
		#expect(!store.needsOnboarding)
		#expect(store.pendingRequiredSchema == nil)
	}

}
