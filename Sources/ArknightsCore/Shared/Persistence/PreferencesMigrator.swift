// SPDX-License-Identifier: MPL-2.0

import Foundation

// Key names live in `LauncherPreferencesStore.Key`; a step names a retired key as a literal.
struct PreferencesMigrationStore {
	let defaults: UserDefaults
	let themeCache: ThemeCacheStore

	func remove(_ key: String) {
		defaults.removeObject(forKey: key)
	}

	func removeKeys(withPrefix prefix: String, keeping: String? = nil) {
		for key in defaults.dictionaryRepresentation().keys
		where key.hasPrefix(prefix) && !(keeping.map(key.hasPrefix) ?? false) {
			defaults.removeObject(forKey: key)
		}
	}

	// Copies the still-valid 0.8 development values into the theme file before their
	// `UserDefaults` keys are removed, so the first 1.0 frame keeps its accent and luminance.
	func importLegacyThemeValues() {
		let accentPrefix = "dynamicThemeAccent.v4."
		for (key, value) in defaults.dictionaryRepresentation() where key.hasPrefix(accentPrefix) {
			guard let values = value as? [String: Any],
				let hue = values["hue"] as? Double,
				let saturation = values["saturation"] as? Double,
				let brightness = values["brightness"] as? Double
			else { continue }
			let snapshot = ThemeAccentSnapshot(
				hue: hue, saturation: saturation, brightness: brightness)
			guard snapshot.isValid else { continue }
			let cacheKey = String(key.dropFirst(accentPrefix.count))
			themeCache.setAccent(
				ThemeCacheDocument.Accent(
					key: cacheKey,
					hue: hue,
					saturation: saturation,
					brightness: brightness
				),
				for: cacheKey
			)
		}

		let versionPrefix = "\(AppConstants.Theme.homeLuminanceVersion)."
		let records = defaults.array(forKey: "homeLuminanceCache") as? [[String: Any]] ?? []
		for record in records {
			guard let identity = record["identity"] as? String,
				identity.hasPrefix(versionPrefix),
				let score = record["score"] as? Double
			else { continue }
			themeCache.setLuminance(
				score, for: identity, limit: AppConstants.Theme.homeLuminanceCacheLimit)
		}
	}
}

// Converts a launch-options blob stored before 0.7.0 into the current format. Before 0.7.0 one
// resolution set both the Retina pixel density and the window size, and a missing
// `usesGameSettings` meant the in-game settings were on. Each field falls back on its own.
private enum PreRetinaLaunchOptions {
	private struct Fields: Decodable {
		let usesGameSettings: Bool?
		let usesHighResolutionMode: Bool?
		let renderingMode: GameRenderingMode?
		let windowSize: GameDisplaySize?
		let hasResolution: Bool

		private enum CodingKeys: String, CodingKey {
			case usesGameSettings, usesHighResolutionMode, renderingMode, windowSize, resolution
		}

		init(from decoder: any Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)
			usesGameSettings = try? container.decodeIfPresent(Bool.self, forKey: .usesGameSettings)
			usesHighResolutionMode = try? container.decodeIfPresent(
				Bool.self, forKey: .usesHighResolutionMode)
			renderingMode = try? container.decodeIfPresent(
				GameRenderingMode.self, forKey: .renderingMode)
			windowSize = try? container.decodeIfPresent(GameDisplaySize.self, forKey: .windowSize)
			hasResolution = container.contains(.resolution)
		}
	}

	// Rewrites the stored blob with explicit values. A blob that is not a JSON object stays as
	// it is; the store reports it when it is read.
	static func convert(_ defaults: UserDefaults) {
		let key = LauncherPreferencesStore.Key.gameLaunchOptions
		guard let data = defaults.data(forKey: key),
			let fields = try? JSONDecoder().decode(Fields.self, from: data),
			let stored = try? JSONDecoder().decode(GameLaunchOptions.self, from: data),
			let encoded = try? JSONEncoder().encode(converted(stored, fields))
		else { return }
		defaults.set(encoded, forKey: key)
	}

	private static func converted(
		_ stored: GameLaunchOptions, _ fields: Fields
	) -> GameLaunchOptions {
		var options = stored
		let retina = fields.usesHighResolutionMode ?? true
		let usesGameSettings = fields.usesGameSettings ?? true
		options.usesGameSettings = usesGameSettings
		options.renderingMode = fields.renderingMode ?? (retina ? .retina : .standard)
		// In-game settings never used the stored resolution, so the window starts at the default.
		let legacyWindow =
			!usesGameSettings && fields.hasResolution
			? legacyWindowSize(for: stored.resolution, retina: retina) : .defaultWindow
		options.windowSize = fields.windowSize ?? legacyWindow
		return options
	}

	// Keeps the window a legacy pixel resolution produced, assuming a 2x Retina display.
	private static func legacyWindowSize(
		for size: GameDisplaySize, retina: Bool
	) -> GameDisplaySize {
		guard retina else { return size }
		let halved = GameDisplaySize(width: size.width / 2, height: size.height / 2)
		guard GameDisplaySize.validDimensions.contains(halved.width),
			GameDisplaySize.validDimensions.contains(halved.height)
		else { return .defaultWindow }
		return halved
	}
}

/// Runs each pending preferences migration once, in version order, and records the last version.
/// Steps must be idempotent. A fresh install runs them on empty defaults.
/// Filesystem moves belong to `LayoutMigrator`; Wine prefix changes belong to `RuntimeMigration`.
package struct PreferencesMigrator {
	struct Step: Sendable {
		let version: Int
		let run: @Sendable (PreferencesMigrationStore) -> Void
	}

	// Append a step with the next version. Never edit or reorder a released step.
	static let steps: [Step] = [
		// Accents cached by the pre-v2 algorithm.
		Step(version: 1) {
			$0.removeKeys(withPrefix: "dynamicThemeAccent.", keeping: "dynamicThemeAccent.v2.")
		},
		// Launch options stored before 0.7.0 kept Retina and the window size in one resolution.
		Step(version: 2) { PreRetinaLaunchOptions.convert($0.defaults) },
		// 0.8 development builds cached theme values in preferences and offered a hidden Retina
		// override. Theme values now live in `AppPaths.themeCache`; Rendering covers Retina.
		Step(version: 3) {
			$0.importLegacyThemeValues()
			$0.removeKeys(withPrefix: "dynamicThemeAccent")
			$0.remove("homeLuminanceCache")
			$0.remove("forceDisableRetina")
		},
		// The developer-only Canary Features toggle was written but never read.
		Step(version: 4) { $0.remove("canaryFeaturesEnabled") },
	]

	private static let versionKey = LauncherPreferencesStore.Key.preferencesMigrationVersion

	let steps: [Step]

	package init() {
		self.init(steps: Self.steps)
	}

	init(steps: [Step]) {
		self.steps = steps
	}

	package func migrate(_ defaults: UserDefaults, themeCacheURL: URL) {
		let applied = defaults.integer(forKey: Self.versionKey)
		let store = PreferencesMigrationStore(
			defaults: defaults,
			themeCache: ThemeCacheStore(
				file: ThemeCacheFile(url: themeCacheURL, log: nil))
		)
		for step in steps where step.version > applied {
			step.run(store)
			defaults.set(step.version, forKey: Self.versionKey)
		}
	}
}
