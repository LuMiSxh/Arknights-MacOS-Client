// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsOnboarding

@MainActor
struct OnboardingProgressStoreTests {
	@Test
	func stepsSavedByEarlierLaunchersResumeAtTheSystemCheck() {
		let (defaults, suiteName) = makeDefaults()
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

		for (completedSchema, expectedRequiredSchema) in [(0, nil), (1, 2), (2, nil)]
			as [(Int, Int?)]
		{
			defaults.removePersistentDomain(forName: suiteName)
			if completedSchema > 0 {
				defaults.set(completedSchema, forKey: "onboarding.completedSchemaVersion")
			}
			#expect(
				OnboardingProgressStore(defaults: defaults).pendingRequiredSchema
					== expectedRequiredSchema)
		}
	}

	private func makeDefaults() -> (UserDefaults, String) {
		let suiteName = "OnboardingProgressStoreTests.\(UUID().uuidString)"
		return (UserDefaults(suiteName: suiteName)!, suiteName)
	}
}
