// SPDX-License-Identifier: MPL-2.0

import Foundation
import Observation

@MainActor
@Observable
package final class LauncherPreferencesController {
	private let log: LauncherLog?
	package var launchOptions: GameLaunchOptions = .default {
		didSet {
			persist(
				Key.gameLaunchOptions, from: Self.launchOptionsSummary(oldValue),
				to: Self.launchOptionsSummary(launchOptions)
			) {
				do {
					try store.setLaunchOptions(launchOptions)
				} catch {
					log?.warning(.settings, "launch-options-save-failed", error: error)
				}
			}
		}
	}
	package var automaticallyChecksLauncherUpdates = Key.automaticLauncherUpdates.defaultValue {
		didSet {
			persist(
				automaticallyChecksLauncherUpdates, from: oldValue,
				for: Key.automaticLauncherUpdates
			) {
				if !isReloading, automaticallyChecksLauncherUpdates {
					onLauncherUpdateCheckRequested?()
				}
			}
		}
	}
	package var automaticallyChecksGameUpdates = Key.automaticGameUpdates.defaultValue {
		didSet {
			persist(automaticallyChecksGameUpdates, from: oldValue, for: Key.automaticGameUpdates) {
				if !isReloading, automaticallyChecksGameUpdates {
					onGameUpdateCheckRequested?()
				}
			}
		}
	}
	package var announcementsEnabled = Key.announcementsEnabled.defaultValue {
		didSet {
			persist(announcementsEnabled, from: oldValue, for: Key.announcementsEnabled) {
				if !isReloading, announcementsEnabled { onAnnouncementCheckRequested?() }
			}
		}
	}
	package var showsServerResetCountdown = Key.showsServerResetCountdown.defaultValue {
		didSet {
			persist(showsServerResetCountdown, from: oldValue, for: Key.showsServerResetCountdown)
		}
	}
	package var showsGameVersion = Key.showsGameVersion.defaultValue {
		didSet { persist(showsGameVersion, from: oldValue, for: Key.showsGameVersion) }
	}
	package var showsBranding = Key.showsBranding.defaultValue {
		didSet { persist(showsBranding, from: oldValue, for: Key.showsBranding) }
	}
	package var playsLauncherMusic = Key.playsLauncherMusic.defaultValue {
		didSet { persist(playsLauncherMusic, from: oldValue, for: Key.playsLauncherMusic) }
	}
	package var launcherMusicURL = Key.launcherMusicURL.defaultValue {
		didSet { persist(launcherMusicURL, from: oldValue, for: Key.launcherMusicURL) }
	}
	package var showsPlayingMusic = Key.showsPlayingMusic.defaultValue {
		didSet { persist(showsPlayingMusic, from: oldValue, for: Key.showsPlayingMusic) }
	}
	package var showsDiscordPresence = Key.showsDiscordPresence.defaultValue {
		didSet {
			persist(showsDiscordPresence, from: oldValue, for: Key.showsDiscordPresence) {
				onDiscordPresenceChanged?()
			}
		}
	}
	package var launcherMusicVolume = Key.launcherMusicVolume.defaultValue {
		didSet { persist(launcherMusicVolume, from: oldValue, for: Key.launcherMusicVolume) }
	}
	package var launcherMusicMuted = Key.launcherMusicMuted.defaultValue {
		didSet { persist(launcherMusicMuted, from: oldValue, for: Key.launcherMusicMuted) }
	}
	package var usesDynamicTheme = Key.usesDynamicTheme.defaultValue {
		didSet {
			persist(usesDynamicTheme, from: oldValue, for: Key.usesDynamicTheme) {
				onDynamicThemeChanged?()
			}
		}
	}
	package var launcherAppearance: LauncherAppearance = .system {
		didSet {
			persist(
				Key.launcherAppearance, from: oldValue.rawValue, to: launcherAppearance.rawValue
			) {
				store.setLauncherAppearance(launcherAppearance)
			}
		}
	}
	package var updateChannel: UpdateChannel = .stable {
		didSet {
			persist(
				Key.updateChannel, from: oldValue.rawValue, to: updateChannel.rawValue
			) {
				store.setUpdateChannel(updateChannel)
			}
		}
	}
	package var homeTheme: HomeTheme = .automatic {
		didSet {
			persist(Key.homeTheme, from: oldValue.rawValue, to: homeTheme.rawValue) {
				store.setHomeTheme(homeTheme)
			}
		}
	}
	package var brandingTheme: HomeTheme = .automatic {
		didSet {
			persist(Key.brandingTheme, from: oldValue.rawValue, to: brandingTheme.rawValue) {
				store.setBrandingTheme(brandingTheme)
			}
		}
	}

	package var resetReminderTiming: ResetReminderTiming = .off {
		didSet {
			persist(
				Key.resetReminderTiming, from: oldValue.rawValue, to: resetReminderTiming.rawValue
			) {
				store.setResetReminderTiming(resetReminderTiming)
				onResetReminderChanged?()
			}
		}
	}

	package var resetReminderRegions: [GameRegion] = [] {
		didSet {
			persist(
				Key.resetReminderRegions, from: Self.listSummary(oldValue),
				to: Self.listSummary(resetReminderRegions)
			) {
				store.setResetReminderRegions(resetReminderRegions)
				onResetReminderChanged?()
			}
		}
	}
	package var usesHardwareCursor = Key.usesHardwareCursor.defaultValue {
		didSet { persist(usesHardwareCursor, from: oldValue, for: Key.usesHardwareCursor) }
	}
	package var dismissedInGameResolutionNote = Key.dismissedInGameResolutionNote.defaultValue {
		didSet {
			persist(
				dismissedInGameResolutionNote, from: oldValue,
				for: Key.dismissedInGameResolutionNote)
		}
	}
	package var batterySaverEnabled = Key.batterySaverEnabled.defaultValue {
		didSet { persist(batterySaverEnabled, from: oldValue, for: Key.batterySaverEnabled) }
	}
	package var debugLoggingEnabled = Key.debugLoggingEnabled.defaultValue {
		didSet {
			persist(debugLoggingEnabled, from: oldValue, for: Key.debugLoggingEnabled) {
				onDebugLoggingChanged?(debugLoggingEnabled)
			}
		}
	}
	/// The runtime patches the user turned off. Each is stored as its own switch.
	package var disabledRuntimePatches: Set<RuntimePatch> = [] {
		didSet {
			persist {
				for patch in oldValue.symmetricDifference(disabledRuntimePatches) {
					logChange(
						Key.runtimePatchEnabled(patch).name,
						from: !oldValue.contains(patch),
						to: !disabledRuntimePatches.contains(patch))
					store.set(
						!disabledRuntimePatches.contains(patch), for: Key.runtimePatchEnabled(patch)
					)
				}
			}
		}
	}
	package var batterySaverFrameRateLimit: GameFrameRateLimit = .fps30 {
		didSet {
			persist(
				Key.batterySaverFrameRateLimit, from: oldValue.rawValue,
				to: batterySaverFrameRateLimit.rawValue
			) {
				store.setBatterySaverFrameRateLimit(batterySaverFrameRateLimit)
			}
		}
	}
	package var screenshotShortcut: ScreenshotShortcut = .off {
		didSet {
			persist(
				Key.screenshotShortcut, from: Self.shortcutKind(oldValue),
				to: Self.shortcutKind(screenshotShortcut)
			) {
				store.setScreenshotShortcut(screenshotShortcut)
				onScreenshotShortcutChanged?(oldValue)
			}
		}
	}
	package var screenshotNotifies = Key.screenshotNotifies.defaultValue {
		didSet { persist(screenshotNotifies, from: oldValue, for: Key.screenshotNotifies) }
	}
	/// The folder the user chose for screenshots, or `nil` for the default folder.
	/// The folder the user chose for screenshots, or `nil` for the default folder.
	package var screenshotDirectory: URL? {
		didSet {
			persist(
				Key.screenshotDirectory, from: oldValue, to: screenshotDirectory, isPrivate: true
			) {
				store.setScreenshotDirectory(screenshotDirectory)
			}
		}
	}

	@ObservationIgnored package var onLauncherUpdateCheckRequested: (() -> Void)?
	@ObservationIgnored package var onGameUpdateCheckRequested: (() -> Void)?
	@ObservationIgnored package var onAnnouncementCheckRequested: (() -> Void)?
	@ObservationIgnored package var onDynamicThemeChanged: (() -> Void)?

	@ObservationIgnored package var onDiscordPresenceChanged: (() -> Void)?
	/// Called with the new value after the user turns debug logging on or off.
	@ObservationIgnored package var onDebugLoggingChanged: ((Bool) -> Void)?
	@ObservationIgnored package var onResetReminderChanged: (() -> Void)?
	/// Called with the previous value after the shortcut changes, including a reset to defaults.
	@ObservationIgnored package var onScreenshotShortcutChanged: ((ScreenshotShortcut) -> Void)?

	private typealias Key = LauncherPreferencesStore.Key
	private let store: LauncherPreferencesStore
	// `init` loads without writing defaults back; later changes persist.
	@ObservationIgnored private var isLoaded = false
	// True while `resetToDefaults` reloads, so a default value does not start a network check.
	@ObservationIgnored private var isReloading = false

	package init(store: LauncherPreferencesStore, log: LauncherLog? = nil) {
		self.store = store
		self.log = log
		reload()
		isLoaded = true
	}

	/// Keeps region and installation locations intact because they point to user files.
	/// Keeps region and installation locations intact because they point to user files.
	package func resetToDefaults(canModifyLaunchOptions: Bool) -> Bool {
		guard canModifyLaunchOptions else { return false }
		isReloading = true
		store.removeResettablePreferences()
		reload()
		isReloading = false
		log?.info(.settings, "reset-to-defaults")
		return true
	}

	/// Reads every preference from the store. `init` and `resetToDefaults` share it, so the
	/// two cannot drift apart.
	private func reload() {
		automaticallyChecksLauncherUpdates = store.value(Key.automaticLauncherUpdates)
		automaticallyChecksGameUpdates = store.value(Key.automaticGameUpdates)
		announcementsEnabled = store.value(Key.announcementsEnabled)
		launchOptions = store.launchOptions(log: log)
		showsServerResetCountdown = store.value(Key.showsServerResetCountdown)
		showsGameVersion = store.value(Key.showsGameVersion)
		showsBranding = store.value(Key.showsBranding)
		playsLauncherMusic = store.value(Key.playsLauncherMusic)
		launcherMusicURL = store.value(Key.launcherMusicURL)
		showsPlayingMusic = store.value(Key.showsPlayingMusic)
		showsDiscordPresence = store.value(Key.showsDiscordPresence)
		launcherMusicVolume = store.value(Key.launcherMusicVolume)
		launcherMusicMuted = store.value(Key.launcherMusicMuted)
		usesDynamicTheme = store.value(Key.usesDynamicTheme)
		usesHardwareCursor = store.value(Key.usesHardwareCursor)
		dismissedInGameResolutionNote = store.value(Key.dismissedInGameResolutionNote)
		batterySaverEnabled = store.value(Key.batterySaverEnabled)
		debugLoggingEnabled = store.value(Key.debugLoggingEnabled)
		disabledRuntimePatches = Set(
			RuntimePatch.allCases.filter { !store.value(Key.runtimePatchEnabled($0)) })
		batterySaverFrameRateLimit = store.batterySaverFrameRateLimit()
		screenshotShortcut = store.screenshotShortcut()
		screenshotNotifies = store.value(Key.screenshotNotifies)
		screenshotDirectory = store.screenshotDirectory()
		launcherAppearance = store.launcherAppearance()
		updateChannel = store.updateChannel()
		homeTheme = store.homeTheme()
		brandingTheme = store.brandingTheme()
		resetReminderTiming = store.resetReminderTiming()
		resetReminderRegions = store.resetReminderRegions()
	}

	private func persist<Value: Sendable & LogValue>(
		_ value: Value, from old: Value, for key: LauncherPreferencesStore.ScalarKey<Value>,
		then effect: () -> Void = {}
	) {
		persist {
			logChange(
				key.name, from: old, to: value,
				isPrivate: Self.privateKeys.contains(key.name))
			store.set(value, for: key)
			effect()
		}
	}

	/// Persists one setting and logs the user-made change as `from`/`to`.
	private func persist(
		_ key: String, from old: any LogValue, to new: any LogValue,
		isPrivate: Bool = false, _ write: () -> Void
	) {
		persist {
			logChange(key, from: old, to: new, isPrivate: isPrivate)
			write()
		}
	}

	/// Runs a preference write only after `init` has loaded the stored values. Reloading then
	/// never writes defaults back or fires change handlers.
	private func persist(_ write: () -> Void) {
		guard isLoaded else { return }
		write()
	}

	/// Logs each user-made change once. Init and reset reloads stay silent; a reset logs one
	/// `reset-to-defaults` line instead.
	private func logChange(
		_ key: String, from old: any LogValue, to new: any LogValue, isPrivate: Bool = false
	) {
		guard !isReloading else { return }
		let oldText = old.logValue
		let newText = new.logValue
		guard oldText != newText else { return }
		log?.info(
			.settings, "changed",
			[
				"key": key,
				"from": isPrivate ? "<set>" : oldText,
				"to": isPrivate ? "<set>" : newText,
			])
	}

	/// Paths and URLs that identify the user or their files log as set, never as values.
	private static let privateKeys: Set<String> = [
		Key.launcherMusicURL.name, Key.screenshotDirectory,
	]

	/// A stable summary without the target display's name or UUID, which identify the hardware.
	private static func launchOptionsSummary(_ options: GameLaunchOptions) -> String {
		[
			"displayMode=\(options.displayMode.rawValue)",
			"resolution=\(options.resolution.storageValue)",
			"fullscreenResolution=\(options.fullscreenResolution.storageValue)",
			"windowSize=\(options.windowSize.storageValue)",
			"usesGameSettings=\(options.usesGameSettings)",
			"renderingMode=\(options.renderingMode.rawValue)",
			"metalPerformanceHUD=\(options.usesMetalPerformanceHUD)",
			"gameMode=\(options.usesGameMode)",
			"synchronization=\(options.synchronizationMode.rawValue)",
			"frameRateLimit=\(options.frameRateLimit.rawValue)",
			"display=\(options.display == nil ? "primary" : "set")",
		].joined(separator: ",")
	}

	private static func listSummary<Element: RawRepresentable>(
		_ values: some Sequence<Element>
	) -> String where Element.RawValue == String {
		let names = values.map(\.rawValue).sorted()
		return names.isEmpty ? "none" : names.joined(separator: ",")
	}

	/// The shortcut kind only; a custom shortcut's label is user text.
	private static func shortcutKind(_ shortcut: ScreenshotShortcut) -> String {
		switch shortcut {
		case .off: "off"
		case .standard: "standard"
		case .custom: "custom"
		}
	}
}
