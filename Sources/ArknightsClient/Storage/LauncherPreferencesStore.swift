// SPDX-License-Identifier: MPL-2.0

import Foundation

@MainActor
/// The single owner of every `UserDefaults`-backed launcher preference; `LauncherViewModel`
/// reads and writes through here rather than touching `UserDefaults` directly, so
/// `resetAllLauncherSettings` and tests have one place to reason about persisted state.
struct LauncherPreferencesStore {
	private enum Key {
		static let automaticLauncherUpdates = "automaticLauncherUpdates"
		static let automaticGameUpdates = "automaticGameUpdates"
		static let announcementsEnabled = "announcementsEnabled"
		static let showsServerResetCountdown = "showsServerResetCountdown"
		static let showsGameVersion = "showsGameVersion"
		static let playsLauncherMusic = "playsLauncherMusic"
		static let launcherMusicURL = "launcherMusicURL"
		static let showsPlayingMusic = "showsPlayingMusic"
		static let launcherMusicVolume = "launcherMusicVolume"
		static let seenAnnouncementIDs = "seenAnnouncementIDs"
		static let presentedLauncherUpdate = "presentedLauncherUpdate"
		static let gameLaunchOptions = "gameLaunchOptions"
		static let installPath = "installPath"
		static let selectedRegion = "selectedRegion"
		static let usesDynamicTheme = "usesDynamicTheme"
	}

	let defaults: UserDefaults

	init(defaults: UserDefaults = .standard) {
		self.defaults = defaults
	}

	func automaticLauncherUpdates() -> Bool {
		bool(for: Key.automaticLauncherUpdates, defaultValue: true)
	}

	func setAutomaticLauncherUpdates(_ value: Bool) {
		defaults.set(value, forKey: Key.automaticLauncherUpdates)
	}

	func automaticGameUpdates() -> Bool {
		bool(for: Key.automaticGameUpdates, defaultValue: true)
	}

	func setAutomaticGameUpdates(_ value: Bool) {
		defaults.set(value, forKey: Key.automaticGameUpdates)
	}

	func announcementsEnabled() -> Bool {
		bool(for: Key.announcementsEnabled, defaultValue: true)
	}

	func setAnnouncementsEnabled(_ value: Bool) {
		defaults.set(value, forKey: Key.announcementsEnabled)
	}

	func showsServerResetCountdown() -> Bool {
		bool(for: Key.showsServerResetCountdown, defaultValue: false)
	}

	func setShowsServerResetCountdown(_ value: Bool) {
		defaults.set(value, forKey: Key.showsServerResetCountdown)
	}

	func showsGameVersion() -> Bool {
		bool(for: Key.showsGameVersion, defaultValue: true)
	}

	func setShowsGameVersion(_ value: Bool) {
		defaults.set(value, forKey: Key.showsGameVersion)
	}

	func playsLauncherMusic() -> Bool {
		bool(for: Key.playsLauncherMusic, defaultValue: true)
	}

	func setPlaysLauncherMusic(_ value: Bool) {
		defaults.set(value, forKey: Key.playsLauncherMusic)
	}

	func launcherMusicURL() -> String {
		defaults.string(forKey: Key.launcherMusicURL)
			?? AppConstants.Music.defaultLauncherMusicURL
	}

	func setLauncherMusicURL(_ value: String) {
		defaults.set(value, forKey: Key.launcherMusicURL)
	}

	func showsPlayingMusic() -> Bool {
		bool(for: Key.showsPlayingMusic, defaultValue: true)
	}

	func setShowsPlayingMusic(_ value: Bool) {
		defaults.set(value, forKey: Key.showsPlayingMusic)
	}

	func launcherMusicVolume() -> Double {
		guard defaults.object(forKey: Key.launcherMusicVolume) != nil else { return 0.5 }
		return defaults.double(forKey: Key.launcherMusicVolume)
	}

	func setLauncherMusicVolume(_ value: Double) {
		defaults.set(value, forKey: Key.launcherMusicVolume)
	}

	func seenAnnouncementIDs() -> Set<String> {
		Set(defaults.stringArray(forKey: Key.seenAnnouncementIDs) ?? [])
	}

	func markAnnouncementSeen(_ id: String) {
		var ids = seenAnnouncementIDs()
		ids.insert(id)
		defaults.set(Array(ids.sorted().suffix(100)), forKey: Key.seenAnnouncementIDs)
	}

	func presentedLauncherUpdate() -> String? {
		defaults.string(forKey: Key.presentedLauncherUpdate)
	}

	func markLauncherUpdatePresented(_ version: String) {
		defaults.set(version, forKey: Key.presentedLauncherUpdate)
	}

	func launchOptions() -> GameLaunchOptions {
		guard
			let data = defaults.data(forKey: Key.gameLaunchOptions),
			let options = try? JSONDecoder().decode(GameLaunchOptions.self, from: data)
		else { return .default }
		return options
	}

	func setLaunchOptions(_ options: GameLaunchOptions) {
		guard let data = try? JSONEncoder().encode(options) else { return }
		defaults.set(data, forKey: Key.gameLaunchOptions)
	}

	func installDirectory(for region: GameRegion, default defaultURL: URL) -> URL {
		guard let path = defaults.string(forKey: "\(Key.installPath).\(region.rawValue)") else {
			return defaultURL
		}
		return URL(filePath: path, directoryHint: .isDirectory)
	}

	func setInstallDirectory(_ url: URL, for region: GameRegion) {
		defaults.set(url.path, forKey: "\(Key.installPath).\(region.rawValue)")
	}

	func selectedRegion() -> GameRegion {
		defaults.string(forKey: Key.selectedRegion).flatMap(GameRegion.init(rawValue:)) ?? .global
	}

	func setSelectedRegion(_ region: GameRegion) {
		defaults.set(region.rawValue, forKey: Key.selectedRegion)
	}

	func usesDynamicTheme() -> Bool {
		bool(for: Key.usesDynamicTheme, defaultValue: true)
	}

	func setUsesDynamicTheme(_ value: Bool) {
		defaults.set(value, forKey: Key.usesDynamicTheme)
	}

	private func bool(for key: String, defaultValue: Bool) -> Bool {
		guard defaults.object(forKey: key) != nil else { return defaultValue }
		return defaults.bool(forKey: key)
	}
}
