// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation

// Persists only setup-assistant progress. Launcher preferences and game files remain owned
// by their existing stores, so bumping the schema can rerun onboarding without migrating or
// rewriting any user choice.
@MainActor
package struct OnboardingProgressStore {
	// 2: launcher 0.7.0 replaced display settings with setup questions, so everyone answers them.
	// 3: launcher 0.8.0 asks every returning player to review setup once more.
	static let currentSchemaVersion = 3
	// Schemas returning players must finish before Skip Setup returns. Give each one a reason in
	// `OnboardingWelcomeView.requiredSetupReason(schema:)`.
	static let requiredSchemaVersions: Set<Int> = [2, 3]

	private typealias Key = LauncherPreferencesStore.Key

	private let defaults: UserDefaults

	package init(defaults: UserDefaults = .standard) {
		self.defaults = defaults
	}

	var needsOnboarding: Bool {
		defaults.integer(forKey: Key.onboardingCompletedSchemaVersion) < Self.currentSchemaVersion
	}

	// The newest required schema a returning player has not finished. First runs, which have
	// no completed schema, can still skip setup.
	var pendingRequiredSchema: Int? {
		let completed = defaults.integer(forKey: Key.onboardingCompletedSchemaVersion)
		guard completed > 0 else { return nil }
		return Self.requiredSchemaVersions.filter {
			$0 > completed && $0 <= Self.currentSchemaVersion
		}.max()
	}

	var savedStep: OnboardingStep? {
		guard defaults.object(forKey: Key.onboardingCurrentStep) != nil else { return nil }
		return OnboardingStep(rawValue: defaults.integer(forKey: Key.onboardingCurrentStep))
	}

	func save(step: OnboardingStep) {
		defaults.set(step.rawValue, forKey: Key.onboardingCurrentStep)
	}

	func complete() {
		defaults.set(Self.currentSchemaVersion, forKey: Key.onboardingCompletedSchemaVersion)
		defaults.removeObject(forKey: Key.onboardingCurrentStep)
	}

	func reset() {
		defaults.removeObject(forKey: Key.onboardingCompletedSchemaVersion)
		defaults.removeObject(forKey: Key.onboardingCurrentStep)
	}
}
