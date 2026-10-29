// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsInfrastructure
import Foundation

/// Derives Discord presence from the game session and the user's preference.
///
/// This type holds no connection state. It maps lifecycle activity to an intent and leaves the
/// transport, retries, and stale-result checks to `DiscordPresenceSession`.
@MainActor
package final class DiscordPresenceController {
	private let lifecycle: LauncherLifecycleStore
	private let preferences: LauncherPreferencesController
	private let region: @MainActor () -> GameRegion
	private let session: DiscordPresenceSession
	private let slot = TaskSlot()
	private var observedSessionID: UUID?
	private var sessionStartedAt: Date?

	package init(
		lifecycle: LauncherLifecycleStore,
		preferences: LauncherPreferencesController,
		log: LauncherLog,
		region: @escaping @MainActor () -> GameRegion
	) {
		self.lifecycle = lifecycle
		self.preferences = preferences
		self.region = region
		session = DiscordPresenceSession(
			clientID: AppConstants.Presence.discordApplicationID,
			log: log,
			makeTransport: {
				DiscordIPCConnection(
					maximumPayloadBytes: AppConstants.Presence.messageMaximumBytes,
					handshakeTimeout: AppConstants.Presence.handshakeTimeout
				)
			}
		)
	}

	package func activityDidChange() {
		let activity = lifecycle.activity
		trackSession(activity)

		guard preferences.showsDiscordPresence else {
			apply(.disabled)
			return
		}
		guard
			activity.isGameProcessRunning,
			let sessionID = activity.activeGameSessionID,
			let startedAt = sessionStartedAt
		else {
			apply(.idle)
			return
		}
		apply(
			.playing(
				DiscordPresenceRequest(
					sessionID: sessionID,
					regionName: Self.regionName(region()),
					startedAt: startedAt
				)
			)
		)
	}

	private func trackSession(_ activity: LauncherActivity) {
		guard activity.isGameProcessRunning, let sessionID = activity.activeGameSessionID else {
			observedSessionID = nil
			sessionStartedAt = nil
			return
		}
		guard observedSessionID != sessionID else { return }
		observedSessionID = sessionID
		sessionStartedAt = Date()
	}

	private func apply(_ intent: DiscordPresenceIntent) {
		slot.replace { [session] _ in
			await session.apply(intent)
		}
	}

	private static func regionName(_ region: GameRegion) -> String {
		switch region {
		case .taiwan: "Taiwan"
		default: region.displayName
		}
	}
}
