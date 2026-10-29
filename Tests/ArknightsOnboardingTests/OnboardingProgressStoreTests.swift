// SPDX-License-Identifier: MPL-2.0

import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsOnboarding

@MainActor
struct OnboardingProgressStoreTests {
	@Test
	func stepsSavedByEarlierLaunchersResumeAtTheSystemCheck() {
		let (defaults, suiteName) = makeIsolatedDefaults("OnboardingProgressStoreTests")
		defer { defaults.removePersistentDomain(forName: suiteName) }
		for savedRawValue in 0...6 {
			defaults.set(savedRawValue, forKey: "onboarding.currentStep")
			#expect(OnboardingProgressStore(defaults: defaults).savedStep == nil)
		}
		defaults.removeObject(forKey: "onboarding.currentStep")

		let store = OnboardingProgressStore(defaults: defaults)
		#expect(store.needsOnboarding)
		store.save(step: .look)
		#expect(store.savedStep == .look)
		#expect(store.needsOnboarding)
		store.complete()
		#expect(!store.needsOnboarding)
		#expect(store.savedStep == nil)
		store.reset()
		#expect(store.needsOnboarding)

		for (completedSchema, expectedRequiredSchema, needsOnboarding) in [
			(0, nil, true), (1, 3, true), (2, 3, true), (3, nil, false),
		] as [(Int, Int?, Bool)] {
			defaults.removePersistentDomain(forName: suiteName)
			if completedSchema > 0 {
				defaults.set(completedSchema, forKey: "onboarding.completedSchemaVersion")
			}
			let store = OnboardingProgressStore(defaults: defaults)
			#expect(store.pendingRequiredSchema == expectedRequiredSchema)
			#expect(store.needsOnboarding == needsOnboarding)
		}
	}

}
