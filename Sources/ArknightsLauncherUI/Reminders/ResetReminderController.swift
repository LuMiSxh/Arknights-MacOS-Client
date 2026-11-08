// SPDX-License-Identifier: MPL-2.0

import AppKit
import ArknightsCore
import ArknightsInfrastructure
import Foundation
import Observation

/// Keeps macOS local notifications in step with the daily reset reminder preferences.
///
/// macOS fires only requests that already exist, so the controller schedules a rolling window of
/// one-shot requests and refills it on every event that can change it. It never polls.
@MainActor
@Observable
final class ResetReminderController {
	/// `true` after macOS refused notifications for this app. Settings shows how to allow them.
	private(set) var isAccessDenied = false

	private let scheduler: any NotificationScheduling
	private let settings: LauncherPreferencesController
	private let installedRegions: () -> [GameRegion]
	private let selectedRegion: () -> GameRegion
	private let now: () -> Date
	private let log: LauncherLog?
	@ObservationIgnored private let slot = TaskSlot()
	@ObservationIgnored private var previousTiming: ResetReminderTiming
	/// Set when the user turns a reminder on, so a later pass still asks even if it replaced the one
	/// that would have. Only a user action sets it, never a launch.
	@ObservationIgnored private var shouldRequestAuthorization = false
	@ObservationIgnored private var observers:
		[(center: NotificationCenter, token: NSObjectProtocol)] = []

	init(
		scheduler: any NotificationScheduling,
		settings: LauncherPreferencesController,
		installedRegions: @escaping () -> [GameRegion],
		selectedRegion: @escaping () -> GameRegion,
		now: @escaping () -> Date = Date.init,
		log: LauncherLog? = nil
	) {
		self.scheduler = scheduler
		self.settings = settings
		self.installedRegions = installedRegions
		self.selectedRegion = selectedRegion
		self.now = now
		self.log = log
		previousTiming = settings.resetReminderTiming
	}

	isolated deinit {
		for observer in observers { observer.center.removeObserver(observer.token) }
	}

	/// Servers the user can pick: the installed ones.
	var availableRegions: [GameRegion] { installedRegions() }

	/// Opens the notification page of System Settings (macOS 13 and later).
	func openSystemNotificationSettings() {
		var address = "x-apple.systempreferences:com.apple.Notifications-Settings.extension"
		if let bundleID = Bundle.main.bundleIdentifier { address += "?id=\(bundleID)" }
		if let url = URL(string: address) { NSWorkspace.shared.open(url) }
	}

	/// Reads the notification permission, fills the window, and listens for the events that move it.
	func start() {
		guard observers.isEmpty else { return }
		observe(.NSSystemTimeZoneDidChange)
		observe(.NSSystemClockDidChange)
		observe(NSWorkspace.didWakeNotification, center: NSWorkspace.shared.notificationCenter)
		observe(NSApplication.didBecomeActiveNotification)
		sync()
	}

	/// Call when the timing or the server selection changed.
	func preferencesDidChange() {
		let timing = settings.resetReminderTiming
		let turnedOn = previousTiming == .off && timing != .off
		previousTiming = timing
		if turnedOn { shouldRequestAuthorization = true }
		if timing == .off { shouldRequestAuthorization = false }
		if turnedOn, effectiveRegions().isEmpty { applyDefaultRegion() }
		sync()
	}

	/// Call when the set of installed servers changed.
	func installedRegionsDidChange() {
		// Onboarding turns the reminder on before the first install, so the default waits for it.
		if settings.resetReminderTiming != .off, settings.resetReminderRegions.isEmpty {
			applyDefaultRegion()
		}
		sync()
	}

	/// The first reminder defaults to the server the launcher shows.
	private func applyDefaultRegion() {
		let installed = installedRegions()
		let selected = selectedRegion()
		if let region = installed.contains(selected) ? selected : installed.first {
			settings.resetReminderRegions = [region]
		}
	}

	/// Re-reads permission and rebuilds the window. IDs encode everything a request shows, so
	/// diffing pending IDs against the plan is enough.
	@discardableResult
	func sync() -> Task<Void, Never> {
		slot.replace { [weak self] token in
			await self?.run(token)
		}
	}

	private func run(_ token: TaskSlot.Token) async {
		let timing = settings.resetReminderTiming
		if timing != .off {
			var authorization = await scheduler.authorization()
			guard slot.owns(token) else { return }
			if authorization == .notDetermined, shouldRequestAuthorization {
				shouldRequestAuthorization = false
				let granted: Bool
				do {
					granted = try await scheduler.requestAuthorization()
				} catch {
					// A failed request never answers the permission question, so the user's
					// setting stays and the status remains `.notDetermined`.
					log?.error("Notification permission request failed: \(error)")
					return
				}
				guard slot.owns(token) else {
					// A newer pass may have read "not determined" while the prompt was open.
					sync()
					return
				}
				authorization = granted ? .authorized : .denied
			}
			switch authorization {
			case .authorized:
				isAccessDenied = false
			case .denied:
				isAccessDenied = true
				// Setting `.off` runs `preferencesDidChange`, which clears the pending requests.
				settings.resetReminderTiming = .off
				return
			case .notDetermined:
				// Nothing was asked yet, so nothing can be delivered.
				return
			}
		} else if isAccessDenied {
			isAccessDenied = await scheduler.authorization() == .denied
			guard slot.owns(token) else { return }
		}

		// At launch the installed servers load after the first pass. Pruning then would drop every
		// pending reminder until they load, so wait for `installedRegionsDidChange`.
		if installedRegions().isEmpty, !settings.resetReminderRegions.isEmpty { return }

		let desired = ResetReminderPlan.notifications(
			now: now(), timing: timing, regions: effectiveRegions())
		let desiredIDs = Set(desired.map(\.identifier))
		let pending = await scheduler.pendingIdentifiers().filter {
			$0.hasPrefix(AppConstants.Reminders.identifierPrefix)
		}
		guard slot.owns(token) else { return }

		scheduler.removePending(identifiers: pending.subtracting(desiredIDs))
		for notification in desired where !pending.contains(notification.identifier) {
			do {
				try await scheduler.add(notification)
			} catch {
				log?.error("Could not schedule \(notification.identifier): \(error)")
			}
			guard slot.owns(token) else { return }
		}
	}

	/// Selected servers that are installed.
	private func effectiveRegions() -> [GameRegion] {
		let installed = Set(installedRegions())
		return settings.resetReminderRegions.filter(installed.contains)
	}

	// App activation re-reads permission, which may have changed in System Settings.
	private func observe(_ name: Notification.Name, center: NotificationCenter = .default) {
		let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
			MainActor.assumeIsolated { _ = self?.sync() }
		}
		observers.append((center, token))
	}
}
