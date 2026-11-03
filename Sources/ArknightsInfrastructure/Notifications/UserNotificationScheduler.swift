// SPDX-License-Identifier: MPL-2.0

import Foundation
@preconcurrency import UserNotifications

/// Thin wrapper over `UNUserNotificationCenter`. Create it only inside an app bundle.
struct UserNotificationScheduler: NotificationScheduling {
	private let center = UNUserNotificationCenter.current()

	func authorization() async -> NotificationAuthorization {
		switch await center.notificationSettings().authorizationStatus {
		case .notDetermined: .notDetermined
		case .denied: .denied
		case .authorized, .provisional, .ephemeral: .authorized
		@unknown default: .denied
		}
	}

	func requestAuthorization() async throws -> Bool {
		try await center.requestAuthorization(options: [.alert, .sound])
	}

	func pendingIdentifiers() async -> Set<String> {
		Set(await center.pendingNotificationRequests().map(\.identifier))
	}

	func add(_ notification: LocalNotification) async throws {
		let content = UNMutableNotificationContent()
		content.title = notification.title
		content.body = notification.body
		content.sound = notification.playsSound ? .default : nil
		if let category = notification.categoryIdentifier {
			content.categoryIdentifier = category
		}
		content.userInfo = notification.userInfo
		let trigger: UNNotificationTrigger? =
			switch notification.trigger {
			case .immediate: nil
			case .calendar(let components):
				UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
			}
		try await center.add(
			UNNotificationRequest(
				identifier: notification.identifier, content: content, trigger: trigger))
	}

	func removePending(identifiers: Set<String>) {
		center.removePendingNotificationRequests(withIdentifiers: Array(identifiers))
	}

	func registerCategories(_ categories: [NotificationCategory]) {
		center.setNotificationCategories(
			Set(
				categories.map { category in
					UNNotificationCategory(
						identifier: category.identifier,
						actions: category.actions.map {
							UNNotificationAction(
								identifier: $0.identifier, title: $0.title, options: [])
						},
						intentIdentifiers: [])
				}))
	}
}
