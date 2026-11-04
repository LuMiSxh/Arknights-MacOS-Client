// SPDX-License-Identifier: MPL-2.0

import AppKit
import ArknightsCore
import ArknightsInfrastructure
import Foundation
import Observation

/// Takes screenshots of the running game and keeps the global shortcut in step with the game.
///
/// The shortcut is registered only while the game process runs and the preference is not off, so
/// it never takes a key from other apps otherwise. Registration follows `LauncherActivity` events.
@MainActor
@Observable
package final class GameScreenshotController {
	/// `true` after macOS refused Screen Recording. Settings shows how to allow it.
	package private(set) var isPermissionDenied = false
	/// `true` while macOS notifications are denied for the app. Settings shows how to allow them.
	package private(set) var isNotificationAccessDenied = false

	private let lifecycle: LauncherLifecycleStore
	private let settings: LauncherPreferencesController
	private let paths: AppPaths
	private let capturer: any WindowImageCapturing
	private let permission: ScreenCapturePermission
	private let scheduler: any NotificationScheduling
	private let region: () -> GameRegion
	private let now: () -> Date
	private let playSound: () -> Void
	private let log: LauncherLog?
	private let makeHotKey:
		(HotKeyCombination, @escaping @Sendable () -> Void) -> (any HotKeyRegistration)?
	@ObservationIgnored private var hotKey: (any HotKeyRegistration)?
	@ObservationIgnored private var registeredShortcut = ScreenshotShortcut.off
	@ObservationIgnored private var isCapturing = false
	@ObservationIgnored private var activityObserver: UUID?

	package convenience init(
		lifecycle: LauncherLifecycleStore,
		settings: LauncherPreferencesController,
		paths: AppPaths,
		scheduler: any NotificationScheduling,
		region: @escaping () -> GameRegion,
		log: LauncherLog? = nil
	) {
		self.init(
			lifecycle: lifecycle, settings: settings, paths: paths,
			capturer: ScreenCaptureKitWindowCapturer(), permission: .system, scheduler: scheduler,
			region: region, log: log)
	}

	init(
		lifecycle: LauncherLifecycleStore,
		settings: LauncherPreferencesController,
		paths: AppPaths,
		capturer: any WindowImageCapturing,
		permission: ScreenCapturePermission,
		scheduler: any NotificationScheduling,
		region: @escaping () -> GameRegion,
		makeHotKey:
			@escaping (HotKeyCombination, @escaping @Sendable () -> Void) -> (
				any HotKeyRegistration
			)? = { GlobalHotKey($0, handler: $1) },
		now: @escaping () -> Date = Date.init,
		playSound: @escaping () -> Void = {
			NSSound(named: NSSound.Name(AppConstants.Screenshots.shutterSoundName))?.play()
		},
		log: LauncherLog? = nil
	) {
		self.lifecycle = lifecycle
		self.settings = settings
		self.paths = paths
		self.capturer = capturer
		self.permission = permission
		self.scheduler = scheduler
		self.region = region
		self.makeHotKey = makeHotKey
		self.now = now
		self.playSound = playSound
		self.log = log
	}

	isolated deinit {
		hotKey?.cancel()
		if let activityObserver { lifecycle.removeActivityObserver(activityObserver) }
	}

	/// True while the game process runs, which is when a screenshot has something to capture.
	package var canTakeScreenshot: Bool { lifecycle.activity.isGameProcessRunning }

	/// Registers the notification actions and starts following the game and the preference.
	package func start() {
		guard activityObserver == nil else { return }
		scheduler.registerCategories([
			NotificationCategory(
				identifier: AppConstants.Screenshots.notificationCategory,
				actions: [
					NotificationAction(
						identifier: AppConstants.Screenshots.showInFinderAction,
						title: "Show in Finder")
				])
		])
		activityObserver = lifecycle.observeActivityChanges { [weak self] in self?.syncHotKey() }
		settings.onScreenshotShortcutChanged = { [weak self] _ in self?.shortcutDidChange() }
		syncHotKey()
	}

	/// Clears the denied flag once the user allowed Screen Recording in System Settings.
	package func refreshPermission() {
		if isPermissionDenied, permission.isGranted() { isPermissionDenied = false }
	}

	/// Reads the notification permission without prompting. Settings calls this when it appears.
	package func refreshNotificationAccess() async {
		guard settings.screenshotNotifies else { return }
		isNotificationAccessDenied = await scheduler.authorization() == .denied
	}

	package func openSystemScreenRecordingSettings() {
		if let url = URL(string: AppConstants.Screenshots.screenRecordingSettingsAddress) {
			NSWorkspace.shared.open(url)
		}
	}

	/// Captures the game window and saves it. Does nothing while the game is not running or a
	/// capture is already in progress.
	@discardableResult
	package func takeScreenshot() -> Task<Void, Never>? {
		let activity = lifecycle.activity
		guard !isCapturing, activity.isGameProcessRunning,
			let sessionID = activity.activeGameSessionID,
			let processIdentifier = activity.gameProcessIdentifier
		else { return nil }
		guard permission.isGranted() else {
			permission.request()
			denyPermission()
			return Task { await report(CaptureError.permissionDenied) }
		}
		isCapturing = true
		return Task {
			defer { isCapturing = false }
			await capture(sessionID: sessionID, processIdentifier: processIdentifier)
		}
	}

	// MARK: - Capture

	private func capture(sessionID: UUID, processIdentifier: Int32) async {
		do {
			let image = try await capturer.captureGameWindow(processIdentifier: processIdentifier)
			// The game may have quit while macOS captured. Then there is nothing to save or report.
			guard isSameSession(sessionID) else { return }
			let directory = settings.screenshotDirectory ?? paths.screenshotsDirectory
			let name = ScreenshotFileWriter.baseName(region: region(), date: now())
			let url = try await ScreenshotFileWriter.writePNG(image, to: directory, baseName: name)
			playSound()
			if settings.screenshotNotifies {
				await post(
					title: "Screenshot saved", body: url.lastPathComponent,
					category: AppConstants.Screenshots.notificationCategory,
					userInfo: [AppConstants.Screenshots.pathUserInfoKey: url.path])
			}
		} catch {
			guard isSameSession(sessionID) else { return }
			await report(error)
		}
	}

	private func isSameSession(_ sessionID: UUID) -> Bool {
		let activity = lifecycle.activity
		return activity.activeGameSessionID == sessionID && activity.isGameProcessRunning
	}

	private func report(_ error: any Error) async {
		let failure = (error as? CaptureError) ?? .saveFailed(error.localizedDescription)
		// ScreenCaptureKit can decline even when the preflight check passed.
		if case .permissionDenied = failure { denyPermission() }
		log?.error("Screenshot failed: \(failure.diagnosticDescription)")
		await post(
			title: "Screenshot failed", body: failure.errorDescription ?? "", category: nil,
			userInfo: [:])
	}

	/// Banners are the only feedback while the game covers the launcher. Asks for permission in
	/// context, because the user just took a screenshot.
	private func post(
		title: String, body: String, category: String?, userInfo: [String: String]
	)
		async
	{
		do {
			var authorization = await scheduler.authorization()
			if authorization == .notDetermined {
				authorization = try await scheduler.requestAuthorization() ? .authorized : .denied
			}
			isNotificationAccessDenied = authorization == .denied
			guard authorization == .authorized else { return }
			try await scheduler.add(
				LocalNotification(
					identifier: UUID().uuidString, title: title, body: body, trigger: .immediate,
					categoryIdentifier: category, userInfo: userInfo, playsSound: false))
		} catch {
			log?.error("Could not post the screenshot notification: \(error)")
		}
	}

	// MARK: - Hot key

	private func shortcutDidChange() {
		let shortcut = settings.screenshotShortcut
		if shortcut != .off, !permission.isGranted() {
			// The user just chose a shortcut, so this is the moment to ask.
			permission.request()
			denyPermission()
			return
		}
		if shortcut != .off { isPermissionDenied = false }
		syncHotKey()
	}

	/// Shows the permission row and turns the shortcut off, so a stored choice never looks active
	/// without access. Resetting runs `shortcutDidChange` once more, which finds nothing to do.
	private func denyPermission() {
		isPermissionDenied = true
		if settings.screenshotShortcut != .off { settings.screenshotShortcut = .off }
	}

	private func syncHotKey() {
		let wanted = lifecycle.activity.isGameProcessRunning ? settings.screenshotShortcut : .off
		guard wanted != registeredShortcut else { return }
		hotKey?.cancel()
		hotKey = nil
		registeredShortcut = .off
		guard let combination = wanted.hotKey else { return }
		guard permission.isGranted() else {
			denyPermission()
			return
		}
		hotKey = makeHotKey(combination) { [weak self] in
			// Carbon calls this on the main thread, outside Swift concurrency.
			Task { @MainActor in self?.takeScreenshot() }
		}
		if hotKey == nil {
			log?.error("Another app already uses the screenshot shortcut.")
		} else {
			registeredShortcut = wanted
		}
	}
}
