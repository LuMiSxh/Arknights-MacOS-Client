// SPDX-License-Identifier: MPL-2.0

import Foundation

@MainActor
package struct LauncherPreferencesStore {
	/// A persisted `UserDefaults` name. `resetToDefaults` removes the names marked `resettable`.
	package protocol StoredPreference: Sendable {
		var name: String { get }
		var resettable: Bool { get }
	}

	/// A scalar `UserDefaults` preference with its single default; `sanitize` runs on every read and write.
	package struct ScalarKey<Value: Sendable>: StoredPreference {
		package let name: String
		let defaultValue: Value
		package let resettable: Bool
		let sanitize: @Sendable (Value) -> Value

		init(
			_ name: String,
			default defaultValue: Value,
			resettable: Bool = true,
			sanitize: @escaping @Sendable (Value) -> Value = { $0 }
		) {
			self.name = name
			self.defaultValue = defaultValue
			self.resettable = resettable
			self.sanitize = sanitize
		}
	}

	/// A `UserDefaults` name stored as a bare string rather than a typed `ScalarKey`.
	package struct RawKey: StoredPreference {
		package let name: String
		package let resettable: Bool

		init(_ name: String, resettable: Bool) {
			self.name = name
			self.resettable = resettable
		}
	}

	package enum Key {
		/// Every fixed `UserDefaults` name this store owns. Case names match the stored strings.
		/// Per-value families such as `dynamicThemeAccent.<cacheKey>` and `installPath.<region>`
		/// are built by `installPath(for:)` and the accent methods.
		enum Name: String, CaseIterable {
			case automaticLauncherUpdates
			case automaticGameUpdates
			case announcementsEnabled
			case showsServerResetCountdown
			case showsGameVersion
			case showsBranding
			case playsLauncherMusic
			case launcherMusicURL
			case showsPlayingMusic
			case showsDiscordPresence
			case launcherMusicVolume
			case launcherMusicMuted
			case canaryFeaturesEnabled
			case usesHardwareCursor
			case dismissedInGameResolutionNote
			case usesDynamicTheme
			case batterySaverEnabled
			case screenshotNotifies
			case screenshotShortcut
			case screenshotDirectory
			case batterySaverFrameRateLimit
			case seenAnnouncementIDs
			case gameLaunchOptions
			case selectedRegion
			case acknowledgedACEWarningRegions
			case resetReminderTiming
			case resetReminderRegions
			case dynamicThemeAccent = "dynamicThemeAccent.v4"
			case homeLuminanceCache
			case lastAppliedDynamicIconHue
			case forceDisableRetina
			case preferencesMigrationVersion
			case onboardingCompletedSchemaVersion = "onboarding.completedSchemaVersion"
			case onboardingCurrentStep = "onboarding.currentStep"
			case launcherAppearance
			case homeTheme
			case brandingTheme
		}

		package static let automaticLauncherUpdates = ScalarKey(
			Name.automaticLauncherUpdates.rawValue, default: true)
		package static let automaticGameUpdates = ScalarKey(
			Name.automaticGameUpdates.rawValue, default: true)
		package static let announcementsEnabled = ScalarKey(
			Name.announcementsEnabled.rawValue, default: true)
		package static let showsServerResetCountdown = ScalarKey(
			Name.showsServerResetCountdown.rawValue, default: false)
		package static let showsGameVersion = ScalarKey(
			Name.showsGameVersion.rawValue, default: true)
		package static let showsBranding = ScalarKey(Name.showsBranding.rawValue, default: true)
		package static let playsLauncherMusic = ScalarKey(
			Name.playsLauncherMusic.rawValue, default: true)
		package static let launcherMusicURL = ScalarKey(
			Name.launcherMusicURL.rawValue,
			default: AppConstants.Music.defaultLauncherMusicURL)
		package static let showsPlayingMusic = ScalarKey(
			Name.showsPlayingMusic.rawValue, default: false)
		package static let showsDiscordPresence = ScalarKey(
			Name.showsDiscordPresence.rawValue, default: false)
		package static let launcherMusicVolume = ScalarKey(
			Name.launcherMusicVolume.rawValue, default: 0.5
		) {
			$0.isFinite ? min(max($0, 0), 1) : 0.5
		}
		package static let launcherMusicMuted = ScalarKey(
			Name.launcherMusicMuted.rawValue, default: false)
		package static let canaryFeaturesEnabled = ScalarKey(
			Name.canaryFeaturesEnabled.rawValue, default: false)
		package static let usesHardwareCursor = ScalarKey(
			Name.usesHardwareCursor.rawValue, default: false)
		package static let dismissedInGameResolutionNote = ScalarKey(
			Name.dismissedInGameResolutionNote.rawValue, default: false)
		package static let usesDynamicTheme = ScalarKey(
			Name.usesDynamicTheme.rawValue, default: true)
		package static let batterySaverEnabled = ScalarKey(
			Name.batterySaverEnabled.rawValue, default: false)
		package static let screenshotNotifies = ScalarKey(
			Name.screenshotNotifies.rawValue, default: true)
		static let screenshotShortcut = Name.screenshotShortcut.rawValue
		// The app is not sandboxed, so a plain path is enough and no bookmark is needed.
		static let screenshotDirectory = Name.screenshotDirectory.rawValue
		static let batterySaverFrameRateLimit = Name.batterySaverFrameRateLimit.rawValue
		static let seenAnnouncementIDs = Name.seenAnnouncementIDs.rawValue
		static let gameLaunchOptions = Name.gameLaunchOptions.rawValue
		static func installPath(for region: GameRegion) -> String {
			"installPath.\(region.rawValue)"
		}
		package static let selectedRegion = Name.selectedRegion.rawValue
		static let acknowledgedACEWarningRegions = Name.acknowledgedACEWarningRegions.rawValue
		static let resetReminderTiming = Name.resetReminderTiming.rawValue
		static let resetReminderRegions = Name.resetReminderRegions.rawValue
		package static let dynamicThemeAccent = Name.dynamicThemeAccent.rawValue
		package static let homeLuminanceCache = Name.homeLuminanceCache.rawValue
		package static let lastAppliedDynamicIconHue = Name.lastAppliedDynamicIconHue.rawValue
		static let forceDisableRetina = Name.forceDisableRetina.rawValue
		static let preferencesMigrationVersion = Name.preferencesMigrationVersion.rawValue
		package static let onboardingCompletedSchemaVersion =
			Name.onboardingCompletedSchemaVersion.rawValue
		package static let onboardingCurrentStep = Name.onboardingCurrentStep.rawValue
		static let launcherAppearance = Name.launcherAppearance.rawValue
		static let homeTheme = Name.homeTheme.rawValue
		static let brandingTheme = Name.brandingTheme.rawValue

		// Every persisted name this store owns. Per-value families such as
		// `dynamicThemeAccent.<cacheKey>` are written under dynamic names and are not listed here.
		package static let all: [any StoredPreference] =
			[
				automaticLauncherUpdates, automaticGameUpdates, announcementsEnabled,
				showsServerResetCountdown, showsGameVersion, showsBranding, playsLauncherMusic,
				launcherMusicURL, showsPlayingMusic, showsDiscordPresence, launcherMusicVolume,
				launcherMusicMuted, usesDynamicTheme, canaryFeaturesEnabled,
				usesHardwareCursor, dismissedInGameResolutionNote, batterySaverEnabled,
				screenshotNotifies,
				RawKey(screenshotShortcut, resettable: true),
				RawKey(screenshotDirectory, resettable: true),
				RawKey(gameLaunchOptions, resettable: true),
				RawKey(batterySaverFrameRateLimit, resettable: true),
				RawKey(acknowledgedACEWarningRegions, resettable: true),
				RawKey(launcherAppearance, resettable: true),
				RawKey(homeTheme, resettable: true),
				RawKey(brandingTheme, resettable: true),
				RawKey(resetReminderTiming, resettable: true),
				RawKey(resetReminderRegions, resettable: true),
				RawKey(seenAnnouncementIDs, resettable: false),
				RawKey(selectedRegion, resettable: false),
				RawKey(forceDisableRetina, resettable: false),
				RawKey(preferencesMigrationVersion, resettable: false),
				RawKey(onboardingCompletedSchemaVersion, resettable: false),
				RawKey(onboardingCurrentStep, resettable: false),
				RawKey(homeLuminanceCache, resettable: false),
				RawKey(lastAppliedDynamicIconHue, resettable: false),
			] + GameRegion.allCases.map { RawKey(installPath(for: $0), resettable: false) }
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
	/// Keeps the most recently seen IDs in the order they were seen.
	package func markAnnouncementSeen(_ id: String) {
		var ids = defaults.stringArray(forKey: Key.seenAnnouncementIDs) ?? []
		ids.removeAll { $0 == id }
		ids.append(id)
		defaults.set(
			Array(ids.suffix(AppConstants.Announcements.seenHistoryLimit)),
			forKey: Key.seenAnnouncementIDs)
	}

	func launchOptions(log: LauncherLog? = nil) -> GameLaunchOptions {
		guard let data = defaults.data(forKey: Key.gameLaunchOptions) else { return .default }
		do {
			return try JSONDecoder().decode(GameLaunchOptions.self, from: data)
		} catch {
			log?.error("Could not read game launch options: \(error.localizedDescription)")
			return .default
		}
	}

	package func setLaunchOptions(_ options: GameLaunchOptions) throws {
		let data = try JSONEncoder().encode(options)
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
			canaryFeaturesEnabled: value(Key.canaryFeaturesEnabled)
		)
	}

	package func setSelectedRegion(_ region: GameRegion) {
		defaults.set(region.rawValue, forKey: Key.selectedRegion)
	}

	package func launcherAppearance() -> LauncherAppearance {
		defaults.string(forKey: Key.launcherAppearance)
			.flatMap(LauncherAppearance.init(rawValue:)) ?? .system
	}

	package func setLauncherAppearance(_ appearance: LauncherAppearance) {
		defaults.set(appearance.rawValue, forKey: Key.launcherAppearance)
	}

	package func homeTheme() -> HomeTheme {
		defaults.string(forKey: Key.homeTheme)
			.flatMap(HomeTheme.init(rawValue:)) ?? .automatic
	}

	package func setHomeTheme(_ theme: HomeTheme) {
		defaults.set(theme.rawValue, forKey: Key.homeTheme)
	}

	package func brandingTheme() -> HomeTheme {
		defaults.string(forKey: Key.brandingTheme)
			.flatMap(HomeTheme.init(rawValue:)) ?? .automatic
	}

	package func setBrandingTheme(_ theme: HomeTheme) {
		defaults.set(theme.rawValue, forKey: Key.brandingTheme)
	}

	package func resetReminderTiming() -> ResetReminderTiming {
		defaults.string(forKey: Key.resetReminderTiming)
			.flatMap(ResetReminderTiming.init(rawValue:)) ?? .off
	}

	package func setResetReminderTiming(_ timing: ResetReminderTiming) {
		defaults.set(timing.rawValue, forKey: Key.resetReminderTiming)
	}

	/// Drops raw values that this build does not recognize.
	package func resetReminderRegions() -> [GameRegion] {
		(defaults.stringArray(forKey: Key.resetReminderRegions) ?? [])
			.compactMap(GameRegion.init(rawValue:))
	}

	package func setResetReminderRegions(_ regions: [GameRegion]) {
		defaults.set(Set(regions).map(\.rawValue).sorted(), forKey: Key.resetReminderRegions)
	}

	package func screenshotShortcut() -> ScreenshotShortcut {
		defaults.string(forKey: Key.screenshotShortcut)
			.flatMap(ScreenshotShortcut.init(storageValue:)) ?? .off
	}

	package func setScreenshotShortcut(_ shortcut: ScreenshotShortcut) {
		defaults.set(shortcut.storageValue, forKey: Key.screenshotShortcut)
	}

	/// The folder the user chose for screenshots, or `nil` for the default folder.
	package func screenshotDirectory() -> URL? {
		defaults.string(forKey: Key.screenshotDirectory)
			.map { URL(filePath: $0, directoryHint: .isDirectory) }
	}

	package func setScreenshotDirectory(_ url: URL?) {
		guard let url else {
			defaults.removeObject(forKey: Key.screenshotDirectory)
			return
		}
		defaults.set(url.path, forKey: Key.screenshotDirectory)
	}

	package func batterySaverFrameRateLimit() -> GameFrameRateLimit {
		let stored = defaults.string(forKey: Key.batterySaverFrameRateLimit)
			.flatMap(GameFrameRateLimit.init(rawValue:))
		guard let stored, GameFrameRateLimit.batterySaverChoices.contains(stored) else {
			return .fps30
		}
		return stored
	}

	package func setBatterySaverFrameRateLimit(_ limit: GameFrameRateLimit) {
		defaults.set(limit.rawValue, forKey: Key.batterySaverFrameRateLimit)
	}

	package func hasAcknowledgedACEWarning(for region: GameRegion) -> Bool {
		acknowledgedACEWarningRegions().contains(region.rawValue)
	}

	package func markACEWarningAcknowledged(for region: GameRegion) {
		var regions = acknowledgedACEWarningRegions()
		regions.insert(region.rawValue)
		defaults.set(Array(regions).sorted(), forKey: Key.acknowledgedACEWarningRegions)
	}

	// Region, install locations, announcement history, and theme caches are kept: they are
	// registered with `resettable: false` in `Key.all`.
	func removeResettablePreferences() {
		for preference in Key.all where preference.resettable {
			defaults.removeObject(forKey: preference.name)
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

	// Records are ordered oldest first. Each identity carries its algorithm version, so a version
	// bump is a miss rather than a stale hit.
	package func homeLuminance(for identity: String) -> Double? {
		homeLuminanceRecords().first { $0.identity == identity }?.score
	}

	// Moves the identity to the newest end and drops the oldest records beyond `limit`.
	package func setHomeLuminance(_ score: Double, for identity: String, limit: Int) {
		var records = homeLuminanceRecords().filter { $0.identity != identity }
		records.append(HomeLuminanceRecord(identity: identity, score: score))
		defaults.set(
			Array(records.suffix(limit)).map(\.storageValue),
			forKey: Key.homeLuminanceCache)
	}

	private func homeLuminanceRecords() -> [HomeLuminanceRecord] {
		(defaults.array(forKey: Key.homeLuminanceCache) as? [[String: Any]] ?? [])
			.compactMap(HomeLuminanceRecord.init(storageValue:))
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

/// One cached Home luminance score, stored as `["identity": String, "score": Double]` so the
/// existing preference format keeps working.
private struct HomeLuminanceRecord: Codable, Equatable, Sendable {
	let identity: String
	let score: Double

	init(identity: String, score: Double) {
		self.identity = identity
		self.score = score
	}

	init?(storageValue: Any) {
		guard let values = storageValue as? [String: Any],
			let identity = values["identity"] as? String,
			let score = values["score"] as? Double
		else { return nil }
		self.init(identity: identity, score: score)
	}

	var storageValue: [String: Any] { ["identity": identity, "score": score] }
}
