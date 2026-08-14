// SPDX-License-Identifier: MPL-2.0

import Foundation

@MainActor
struct LauncherPreferencesStore {
	private enum Key {
		static let automaticLauncherUpdates = "automaticLauncherUpdates"
		static let automaticGameUpdates = "automaticGameUpdates"
		static let gameLaunchOptions = "gameLaunchOptions"
		static let installPath = "installPath.global"
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

	func installDirectory(default defaultURL: URL) -> URL {
		guard let path = defaults.string(forKey: Key.installPath) else { return defaultURL }
		return URL(filePath: path, directoryHint: .isDirectory)
	}

	func setInstallDirectory(_ url: URL) {
		defaults.set(url.path, forKey: Key.installPath)
	}

	private func bool(for key: String, defaultValue: Bool) -> Bool {
		guard defaults.object(forKey: key) != nil else { return defaultValue }
		return defaults.bool(forKey: key)
	}
}
