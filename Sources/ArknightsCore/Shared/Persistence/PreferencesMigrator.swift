// SPDX-License-Identifier: MPL-2.0

import Foundation

/// The narrow `UserDefaults` operations a preferences migration may use.
/// Key names live in `LauncherPreferencesStore.Key`; a step names a retired key as a literal.
struct PreferencesMigrationStore {
	let defaults: UserDefaults

	func remove(_ key: String) {
		defaults.removeObject(forKey: key)
	}

	/// Removes every key that starts with `prefix`, except keys that start with `keeping`.
	func removeKeys(withPrefix prefix: String, keeping: String? = nil) {
		for key in defaults.dictionaryRepresentation().keys
		where key.hasPrefix(prefix) && !(keeping.map(key.hasPrefix) ?? false) {
			defaults.removeObject(forKey: key)
		}
	}

	/// Moves a value to a new key. An existing value under the new key wins.
	func rename(_ key: String, to newKey: String) {
		guard let value = defaults.object(forKey: key) else { return }
		if defaults.object(forKey: newKey) == nil { defaults.set(value, forKey: newKey) }
		defaults.removeObject(forKey: key)
	}
}

/// Runs each pending preferences migration once, in version order, and records the last version.
/// Steps must be idempotent. A fresh install runs them on empty defaults.
/// Filesystem moves belong to `AppStorageMigrator`; Wine prefix changes belong to `RuntimeMigration`.
package struct PreferencesMigrator {
	struct Step: Sendable {
		let version: Int
		let run: @Sendable (PreferencesMigrationStore) -> Void
	}

	/// Append a step with the next version. Never edit or reorder a released step.
	static let steps: [Step] = [
		// Accents cached by the pre-v2 algorithm.
		Step(version: 1) {
			$0.removeKeys(withPrefix: "dynamicThemeAccent.", keeping: "dynamicThemeAccent.v2.")
		}
	]

	private static let versionKey = LauncherPreferencesStore.Key.preferencesMigrationVersion

	let steps: [Step]

	package init() {
		self.init(steps: Self.steps)
	}

	init(steps: [Step]) {
		precondition(
			zip(steps, steps.dropFirst()).allSatisfy { $0.version < $1.version },
			"Preferences migration versions must increase.")
		self.steps = steps
	}

	package func migrate(_ defaults: UserDefaults) {
		let applied = defaults.integer(forKey: Self.versionKey)
		let store = PreferencesMigrationStore(defaults: defaults)
		for step in steps where step.version > applied {
			step.run(store)
			defaults.set(step.version, forKey: Self.versionKey)
		}
	}
}
