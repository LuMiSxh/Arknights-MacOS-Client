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

		store.save(step: .icons)

		#expect(store.savedStep == .icons)
		#expect(store.needsOnboarding)

		store.save(step: .finish)
		store.complete()

		#expect(!store.needsOnboarding)
		#expect(store.savedStep == nil)

		store.reset()

		#expect(store.needsOnboarding)
	}

	private func makeDefaults() -> (UserDefaults, String) {
		let suiteName = "OnboardingProgressStoreTests.\(UUID().uuidString)"
		return (UserDefaults(suiteName: suiteName)!, suiteName)
	}
}
