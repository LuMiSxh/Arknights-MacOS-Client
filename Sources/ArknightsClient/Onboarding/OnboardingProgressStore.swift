// SPDX-License-Identifier: MPL-2.0

import Foundation

/// Persists only setup-assistant progress. Launcher preferences and game files remain owned
/// by their existing stores, so bumping the schema can rerun onboarding without migrating or
/// rewriting any user choice.
@MainActor
struct OnboardingProgressStore {
	static let currentSchemaVersion = 1

	private enum Key {
		static let completedSchemaVersion = "onboarding.completedSchemaVersion"
		static let currentStep = "onboarding.currentStep"
	}

	private let defaults: UserDefaults

	init(defaults: UserDefaults = .standard) {
		self.defaults = defaults
	}

	var needsOnboarding: Bool {
		defaults.integer(forKey: Key.completedSchemaVersion) < Self.currentSchemaVersion
	}

	var savedStep: OnboardingStep? {
		guard defaults.object(forKey: Key.currentStep) != nil else { return nil }
		return OnboardingStep(rawValue: defaults.integer(forKey: Key.currentStep))
	}

	func save(step: OnboardingStep) {
		defaults.set(step.rawValue, forKey: Key.currentStep)
	}

	func complete() {
		defaults.set(Self.currentSchemaVersion, forKey: Key.completedSchemaVersion)
		defaults.removeObject(forKey: Key.currentStep)
	}

	func reset() {
		defaults.removeObject(forKey: Key.completedSchemaVersion)
		defaults.removeObject(forKey: Key.currentStep)
	}
}
