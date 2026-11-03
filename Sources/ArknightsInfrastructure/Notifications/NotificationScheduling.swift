// SPDX-License-Identifier: MPL-2.0

import Foundation

/// Authorization state for local notifications, reduced to what the launcher acts on.
package enum NotificationAuthorization: Sendable, Equatable {
	case notDetermined
	case denied
	case authorized
}

/// A local notification that is delivered now or at a calendar date.
package struct LocalNotification: Sendable, Equatable {
	package enum Trigger: Sendable, Equatable {
		/// Delivered as soon as it is added.
		case immediate
		/// Delivered once when the components match. Use UTC components for an absolute instant.
		case calendar(DateComponents)
	}

	package let identifier: String
	package let title: String
	package let body: String
	package let trigger: Trigger

	package init(identifier: String, title: String, body: String, trigger: Trigger) {
		self.identifier = identifier
		self.title = title
		self.body = body
		self.trigger = trigger
	}
}

/// Posts and tracks local notifications for one app. Feature code depends on this protocol only.
package protocol NotificationScheduling: Sendable {
	func authorization() async -> NotificationAuthorization
	/// Asks the system for permission to alert and play sounds. Returns whether it was granted.
	func requestAuthorization() async throws -> Bool
	func pendingIdentifiers() async -> Set<String>
	func add(_ notification: LocalNotification) async throws
	func removePending(identifiers: Set<String>)
}

/// Returns the system scheduler inside an app bundle. Outside a bundle, `UNUserNotificationCenter`
/// traps, so tests and command-line runs get a scheduler that does nothing.
package func makeNotificationScheduler() -> any NotificationScheduling {
	Bundle.main.bundleURL.pathExtension == "app"
		? UserNotificationScheduler() : UnavailableNotificationScheduler()
}

private struct UnavailableNotificationScheduler: NotificationScheduling {
	func authorization() async -> NotificationAuthorization { .denied }
	func requestAuthorization() async throws -> Bool { false }
	func pendingIdentifiers() async -> Set<String> { [] }
	func add(_ notification: LocalNotification) async throws {}
	func removePending(identifiers: Set<String>) {}
}
