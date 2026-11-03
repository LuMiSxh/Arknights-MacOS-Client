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
	/// Names a registered `NotificationCategory`, which adds its actions to the notification.
	package let categoryIdentifier: String?
	/// Values the app reads back when the user responds to the notification.
	package let userInfo: [String: String]
	package let playsSound: Bool

	package init(
		identifier: String, title: String, body: String, trigger: Trigger,
		categoryIdentifier: String? = nil, userInfo: [String: String] = [:],
		playsSound: Bool = true
	) {
		self.identifier = identifier
		self.title = title
		self.body = body
		self.trigger = trigger
		self.categoryIdentifier = categoryIdentifier
		self.userInfo = userInfo
		self.playsSound = playsSound
	}
}

/// A button on a notification.
package struct NotificationAction: Sendable, Equatable {
	package let identifier: String
	package let title: String

	package init(identifier: String, title: String) {
		self.identifier = identifier
		self.title = title
	}
}

/// A named set of actions that notifications can carry.
package struct NotificationCategory: Sendable, Equatable {
	package let identifier: String
	package let actions: [NotificationAction]

	package init(identifier: String, actions: [NotificationAction]) {
		self.identifier = identifier
		self.actions = actions
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
	/// Replaces the categories the system knows. Register them before the first notification.
	func registerCategories(_ categories: [NotificationCategory])
}

extension NotificationScheduling {
	package func registerCategories(_ categories: [NotificationCategory]) {}
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
