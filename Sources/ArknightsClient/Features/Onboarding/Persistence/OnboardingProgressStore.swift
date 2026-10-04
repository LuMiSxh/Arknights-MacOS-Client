// SPDX-License-Identifier: MPL-2.0

import Foundation

/// Persists only setup-assistant progress. Launcher preferences and game files remain owned
/// by their existing stores, so bumping the schema can rerun onboarding without migrating or
/// rewriting any user choice.
@MainActor
struct OnboardingProgressStore {
	/// 2: launcher 0.6.2 replaced display settings with setup questions, so everyone answers them.
	static let currentSchemaVersion = 2
	/// Schemas returning players must finish before Skip Setup returns. Give each one a reason in
	/// `OnboardingStrings.requiredSetupReason(schema:)`.
	static let requiredSchemaVersions: Set<Int> = [2]

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

	/// The newest required schema a returning player has not finished. First runs, which have
	/// no completed schema, can still skip setup.
	var pendingRequiredSchema: Int? {
		let completed = defaults.integer(forKey: Key.completedSchemaVersion)
		guard completed > 0 else { return nil }
		return Self.requiredSchemaVersions.filter {
			$0 > completed && $0 <= Self.currentSchemaVersion
		}.max()
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
