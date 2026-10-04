// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@MainActor
struct OnboardingProgressStoreTests {
	@Test
	func onboardingProgressPersistsUntilCompletionAndReset() {
		let (defaults, suiteName) = makeDefaults()
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let store = OnboardingProgressStore(defaults: defaults)

		#expect(store.needsOnboarding)
		#expect(store.savedStep == nil)

		store.save(step: .look)

		#expect(store.savedStep == .look)
		#expect(store.needsOnboarding)

		store.save(step: .finish)
		store.complete()

		#expect(!store.needsOnboarding)
		#expect(store.savedStep == nil)

		store.reset()

		#expect(store.needsOnboarding)
	}

	@Test(arguments: 0...6)
	func stepsSavedByEarlierLaunchersResumeAtTheSystemCheck(savedRawValue: Int) {
		let (defaults, suiteName) = makeDefaults()
		defer { defaults.removePersistentDomain(forName: suiteName) }
		defaults.set(savedRawValue, forKey: "onboarding.currentStep")

		#expect(OnboardingProgressStore(defaults: defaults).savedStep == nil)
	}

	@Test
	func stepsFollowTheSetupRouteInOrder() {
		#expect(
			OnboardingStep.allCases == [.welcome, .region, .display, .look, .extras, .finish])
		#expect(OnboardingStep.allCases.map(\.rawValue) == Array(10...15))
		#expect(OnboardingStep.welcome.previous == nil)
		#expect(OnboardingStep.finish.next == nil)
		for (step, following) in zip(OnboardingStep.allCases, OnboardingStep.allCases.dropFirst()) {
			#expect(step.next == following)
			#expect(following.previous == step)
		}
	}

	@Test(
		arguments: [
			(0, nil),
			(1, 2),
			(2, nil),
		] as [(Int, Int?)])
	func requiredSetupAppliesOnlyToReturningPlayersBelowARequiredSchema(
		completedSchema: Int,
		expectedRequiredSchema: Int?
	) {
		let (defaults, suiteName) = makeDefaults()
		defer { defaults.removePersistentDomain(forName: suiteName) }
		if completedSchema > 0 {
			defaults.set(completedSchema, forKey: "onboarding.completedSchemaVersion")
		}

		#expect(
			OnboardingProgressStore(defaults: defaults).pendingRequiredSchema
				== expectedRequiredSchema)
	}

	private func makeDefaults() -> (UserDefaults, String) {
		let suiteName = "OnboardingProgressStoreTests.\(UUID().uuidString)"
		return (UserDefaults(suiteName: suiteName)!, suiteName)
	}
}
