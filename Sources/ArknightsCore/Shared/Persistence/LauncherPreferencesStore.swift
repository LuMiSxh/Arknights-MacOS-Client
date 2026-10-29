// SPDX-License-Identifier: MPL-2.0

import Foundation

@MainActor
package struct LauncherPreferencesStore {
	/// A scalar `UserDefaults` preference with its single default; `sanitize` runs on every read and write.
	package struct ScalarKey<Value: Sendable>: Sendable {
		package let name: String
		let defaultValue: Value
		let sanitize: @Sendable (Value) -> Value

		init(
			_ name: String,
			default defaultValue: Value,
			sanitize: @escaping @Sendable (Value) -> Value = { $0 }
		) {
			self.name = name
			self.defaultValue = defaultValue
			self.sanitize = sanitize
		}
	}

	package enum Key {
		package static let automaticLauncherUpdates = ScalarKey(
			"automaticLauncherUpdates", default: true)
		package static let automaticGameUpdates = ScalarKey("automaticGameUpdates", default: true)
		package static let announcementsEnabled = ScalarKey("announcementsEnabled", default: true)
		package static let showsServerResetCountdown = ScalarKey(
			"showsServerResetCountdown", default: false)
		package static let showsGameVersion = ScalarKey("showsGameVersion", default: true)
		package static let showsBranding = ScalarKey("showsBranding", default: true)
		package static let playsLauncherMusic = ScalarKey("playsLauncherMusic", default: true)
		package static let launcherMusicURL = ScalarKey(
			"launcherMusicURL", default: AppConstants.Music.defaultLauncherMusicURL)
		package static let showsPlayingMusic = ScalarKey("showsPlayingMusic", default: false)
		package static let showsDiscordPresence = ScalarKey("showsDiscordPresence", default: false)
		package static let launcherMusicVolume = ScalarKey("launcherMusicVolume", default: 0.5) {
			$0.isFinite ? min(max($0, 0), 1) : 0.5
		}
		package static let launcherMusicMuted = ScalarKey("launcherMusicMuted", default: false)
		package static let canaryFeaturesEnabled = ScalarKey(
			"canaryFeaturesEnabled", default: false)
		package static let taiwanClientEnabled = ScalarKey("taiwanClientEnabled", default: false)
		package static let usesHardwareCursor = ScalarKey("usesHardwareCursor", default: false)
		package static let dismissedInGameResolutionNote = ScalarKey(
			"dismissedInGameResolutionNote", default: false)
		package static let usesDynamicTheme = ScalarKey("usesDynamicTheme", default: true)
		static let seenAnnouncementIDs = "seenAnnouncementIDs"
		static let gameLaunchOptions = "gameLaunchOptions"
		static func installPath(for region: GameRegion) -> String {
			"installPath.\(region.rawValue)"
		}
		package static let selectedRegion = "selectedRegion"
		static let acknowledgedACEWarningRegions = "acknowledgedACEWarningRegions"
		package static let dynamicThemeAccent = "dynamicThemeAccent.v2"
		package static let lastAppliedDynamicIconHue = "lastAppliedDynamicIconHue"
		static let forceDisableRetina = "forceDisableRetina"
		static let preferencesMigrationVersion = "preferencesMigrationVersion"
		package static let onboardingCompletedSchemaVersion = "onboarding.completedSchemaVersion"
		package static let onboardingCurrentStep = "onboarding.currentStep"
	}

	package let defaults: UserDefaults

	package init(defaults: UserDefaults = .standard) {
		self.defaults = defaults
	}

	package func value<Value>(_ key: ScalarKey<Value>) -> Value {
		key.sanitize(defaults.object(forKey: key.name) as? Value ?? key.defaultValue)
	}

	package func set<Value>(_ value: Value, for key: ScalarKey<Value>) {
		defaults.set(key.sanitize(value), forKey: key.name)
	}

	package func seenAnnouncementIDs() -> Set<String> {
		Set(defaults.stringArray(forKey: Key.seenAnnouncementIDs) ?? [])
	}

	/// Keeps the 100 most recently seen IDs in the order they were seen.
	package func markAnnouncementSeen(_ id: String) {
		var ids = defaults.stringArray(forKey: Key.seenAnnouncementIDs) ?? []
		ids.removeAll { $0 == id }
		ids.append(id)
		defaults.set(Array(ids.suffix(100)), forKey: Key.seenAnnouncementIDs)
	}

	func launchOptions() -> GameLaunchOptions {
		guard
			let data = defaults.data(forKey: Key.gameLaunchOptions),
			let options = try? JSONDecoder().decode(GameLaunchOptions.self, from: data)
		else { return .default }
		return options
	}

	package func setLaunchOptions(_ options: GameLaunchOptions) {
		guard let data = try? JSONEncoder().encode(options) else { return }
		defaults.set(data, forKey: Key.gameLaunchOptions)
	}

	package func installDirectory(for region: GameRegion, default defaultURL: URL) -> URL {
		guard let path = defaults.string(forKey: Key.installPath(for: region)) else {
			return defaultURL
		}
		return URL(filePath: path, directoryHint: .isDirectory)
	}

	package func persistedInstallDirectories() -> [GameRegion: URL] {
		Dictionary(
			uniqueKeysWithValues: GameRegion.allCases.compactMap { region in
				guard let path = defaults.string(forKey: Key.installPath(for: region))
				else {
					return nil
				}
				return (region, URL(filePath: path, directoryHint: .isDirectory))
			})
	}

	package func updateInstallDirectories(
		_ updates: [GameRegion: URL],
		replacing expected: [GameRegion: URL]
	) {
		let current = persistedInstallDirectories()
		for (region, directory) in updates {
			guard
				let expectedDirectory = expected[region],
				let currentDirectory = current[region],
				currentDirectory.standardizedFileURL.path
					== expectedDirectory.standardizedFileURL.path
			else { continue }
			setInstallDirectory(directory, for: region)
		}
	}

	package func setInstallDirectory(_ url: URL, for region: GameRegion) {
		defaults.set(url.path, forKey: Key.installPath(for: region))
	}

	package func selectedRegion() -> GameRegion {
		let region = defaults.string(forKey: Key.selectedRegion).flatMap(GameRegion.init(rawValue:))
		guard let region, regionAccess().allows(region) else { return .global }
		return region
	}

	package func regionAccess() -> RegionAccess {
		RegionAccess(
			canaryFeaturesEnabled: value(Key.canaryFeaturesEnabled),
			taiwanClientEnabled: value(Key.taiwanClientEnabled)
		)
	}

	package func setSelectedRegion(_ region: GameRegion) {
		defaults.set(region.rawValue, forKey: Key.selectedRegion)
	}

	package func hasAcknowledgedACEWarning(for region: GameRegion) -> Bool {
		acknowledgedACEWarningRegions().contains(region.rawValue)
	}

	package func markACEWarningAcknowledged(for region: GameRegion) {
		var regions = acknowledgedACEWarningRegions()
		regions.insert(region.rawValue)
		defaults.set(Array(regions).sorted(), forKey: Key.acknowledgedACEWarningRegions)
	}

	// Region, install locations, announcement history, and theme caches are kept.
	func removeResettablePreferences() {
		for key in [
			Key.automaticLauncherUpdates.name, Key.automaticGameUpdates.name,
			Key.announcementsEnabled.name, Key.gameLaunchOptions,
			Key.showsServerResetCountdown.name, Key.showsGameVersion.name, Key.showsBranding.name,
			Key.playsLauncherMusic.name, Key.launcherMusicURL.name, Key.showsPlayingMusic.name,
			Key.launcherMusicVolume.name, Key.launcherMusicMuted.name,
			Key.showsDiscordPresence.name,
			Key.usesDynamicTheme.name, Key.canaryFeaturesEnabled.name,
			Key.taiwanClientEnabled.name, Key.acknowledgedACEWarningRegions,
			Key.usesHardwareCursor.name, Key.dismissedInGameResolutionNote.name,
		] {
			defaults.removeObject(forKey: key)
		}
	}

	package func forceDisableRetina() -> Bool {
		defaults.bool(forKey: Key.forceDisableRetina)
	}

	package func dynamicThemeAccent(for cacheKey: String) -> ThemeAccentSnapshot? {
		guard
			let values = defaults.dictionary(forKey: "\(Key.dynamicThemeAccent).\(cacheKey)"),
			let hue = values["hue"] as? Double,
			let saturation = values["saturation"] as? Double,
			let brightness = values["brightness"] as? Double
		else { return nil }
		let snapshot = ThemeAccentSnapshot(
			hue: hue,
			saturation: saturation,
			brightness: brightness
		)
		return snapshot.isValid ? snapshot : nil
	}

	package func setDynamicThemeAccent(_ snapshot: ThemeAccentSnapshot?, for cacheKey: String) {
		let key = "\(Key.dynamicThemeAccent).\(cacheKey)"
		guard let snapshot else {
			defaults.removeObject(forKey: key)
			return
		}
		defaults.set(
			[
				"hue": snapshot.hue,
				"saturation": snapshot.saturation,
				"brightness": snapshot.brightness,
			],
			forKey: key
		)
	}

	/// The hue last persisted to the app bundle's icon via `NSWorkspace.setIcon`.
	package func lastAppliedDynamicIconHue() -> Double? {
		defaults.object(forKey: Key.lastAppliedDynamicIconHue) as? Double
	}

	package func setLastAppliedDynamicIconHue(_ hue: Double?) {
		guard let hue else {
			defaults.removeObject(forKey: Key.lastAppliedDynamicIconHue)
			return
		}
		defaults.set(hue, forKey: Key.lastAppliedDynamicIconHue)
	}

	private func acknowledgedACEWarningRegions() -> Set<String> {
		Set(defaults.stringArray(forKey: Key.acknowledgedACEWarningRegions) ?? [])
	}
}
