// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation
import Testing

@testable import ArknightsLauncherUI

struct LauncherAnnouncementServiceTests {
	@Test
	func eligibilityHonorsVersionWindowDatesAndSeenIDs() throws {
		for (candidate, current, expected) in [
			("v1.2.4", "1.2.3", true),
			("1.2.3", "v1.2.3-rc.1", true),
			("v1.2.3-rc.10", "1.2.3-rc.2", true),
			("v1.2.3-alpha", "1.2.3-alpha.1", false),
			("v1.2.3+build.7", "1.2.3+build.6", false),
			("v1.2.3", "not-a-version", false),
		] {
			#expect(
				(LauncherAnnouncement.compare(candidate, current) == .orderedDescending) == expected
			)
		}
		let now = Date(timeIntervalSince1970: 1_800_000_000)
		let announcement = LauncherAnnouncement(
			id: "feedback",
			enabled: true,
			title: "Feedback",
			body: "Tell us what you think.",
			actionTitle: nil,
			actionURL: nil,
			minimumVersion: "0.2.0",
			maximumVersion: "0.3.0",
			startsAt: now.addingTimeInterval(-60),
			endsAt: now.addingTimeInterval(60)
		)

		#expect(
			announcement.isEligible(currentVersion: "0.2.0", now: now, seenIDs: [])
		)
		#expect(
			!announcement.isEligible(currentVersion: "0.1.0", now: now, seenIDs: [])
		)
		#expect(
			!announcement.isEligible(
				currentVersion: "0.2.0", now: now, seenIDs: ["feedback"])
		)
	}
}
