// SPDX-License-Identifier: MPL-2.0

import Foundation

@MainActor
struct LauncherPreferencesStore {
	private enum Key {
		static let automaticLauncherUpdates = "automaticLauncherUpdates"
		static let automaticGameUpdates = "automaticGameUpdates"
		static let announcementsEnabled = "announcementsEnabled"
		static let showsServerResetCountdown = "showsServerResetCountdown"
		static let showsGameVersion = "showsGameVersion"
		static let seenAnnouncementIDs = "seenAnnouncementIDs"
		static let presentedLauncherUpdate = "presentedLauncherUpdate"
		static let gameLaunchOptions = "gameLaunchOptions"
		static let installPath = "installPath"
		static let selectedRegion = "selectedRegion"
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

	private func bool(for key: String, defaultValue: Bool) -> Bool {
		guard defaults.object(forKey: key) != nil else { return defaultValue }
		return defaults.bool(forKey: key)
	}
}
