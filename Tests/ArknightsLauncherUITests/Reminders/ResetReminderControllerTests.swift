// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsInfrastructure
import ArknightsTestSupport
import Foundation
import Synchronization
import Testing

@testable import ArknightsLauncherUI

private final class FakeScheduler: NotificationScheduling {
	private struct State {
		var authorization: NotificationAuthorization
		var grantsRequest: Bool
		var pending: [String: LocalNotification] = [:]
		var requestCount = 0
		var pendingReads = 0
	}

	private let state: Mutex<State>
	/// When set, the first read of pending requests waits until `releaseFirstRead` fires.
	let firstReadReached = Signal()
	let releaseFirstRead = Signal()
	private let holdsFirstRead: Bool

	init(
		authorization: NotificationAuthorization = .authorized, grantsRequest: Bool = true,
		holdsFirstRead: Bool = false
	) {
		state = Mutex(State(authorization: authorization, grantsRequest: grantsRequest))
		self.holdsFirstRead = holdsFirstRead
	}

	var pending: [String: LocalNotification] { state.withLock { $0.pending } }
	var requestCount: Int { state.withLock { $0.requestCount } }

	func authorization() async -> NotificationAuthorization { state.withLock { $0.authorization } }

	func requestAuthorization() async throws -> Bool {
		state.withLock {
			$0.requestCount += 1
			if $0.authorization == .notDetermined {
				$0.authorization = $0.grantsRequest ? .authorized : .denied
			}
			return $0.grantsRequest
		}
	}

	func pendingIdentifiers() async -> Set<String> {
		let isFirst = state.withLock { value -> Bool in
			value.pendingReads += 1
			return value.pendingReads == 1
		}
		if holdsFirstRead, isFirst {
			firstReadReached.fire()
			await releaseFirstRead.wait()
		}
		return Set(state.withLock { $0.pending.keys })
	}

	func add(_ notification: LocalNotification) async throws {
		state.withLock { $0.pending[notification.identifier] = notification }
	}

	func removePending(identifiers: Set<String>) {
		state.withLock { value in
			for identifier in identifiers { value.pending[identifier] = nil }
		}
	}
}

@MainActor
private final class Harness {
	let scheduler: FakeScheduler
	let settings: LauncherPreferencesController
	let controller: ResetReminderController
	var installed: [GameRegion]
	var selected: GameRegion = .global
	private let suiteName = "ResetReminderControllerTests.\(UUID().uuidString)"

	init(scheduler: FakeScheduler, now: Date, installed: [GameRegion] = [.global, .japan]) {
		self.scheduler = scheduler
		self.installed = installed
		let defaults = UserDefaults(suiteName: suiteName)!
		settings = LauncherPreferencesController(
			store: LauncherPreferencesStore(defaults: defaults))
		var box: Harness?
		controller = ResetReminderController(
			scheduler: scheduler,
			settings: settings,
			installedRegions: { box?.installed ?? [] },
			selectedRegion: { box?.selected ?? .global },
			now: { now }
		)
		box = self
		settings.onResetReminderChanged = { [controller] in controller.preferencesDidChange() }
	}

	func cleanUp() {
		UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
	}

	/// Applies a preference change and waits for the reschedule it starts.
	func settle() async {
		await controller.sync().value
	}
}

private func date(_ iso: String) -> Date {
	ISO8601DateFormatter().date(from: iso)!
}

private func fireDates(_ scheduler: FakeScheduler, region: GameRegion) -> [Date] {
	scheduler.pending.values
		.filter { $0.identifier.hasPrefix("reset.\(region.rawValue).") }
		.compactMap { notification -> Date? in
			guard case .calendar(let components) = notification.trigger else { return nil }
			return components.date
		}
		.sorted()
}

@MainActor
@Suite struct ResetReminderControllerTests {
	// Global resets at 04:00 UTC-7, which is 11:00 UTC.
	private let now = date("2026-11-03T12:00:00Z")

	@Test(arguments: [
		(ResetReminderTiming.minutes60, "2026-11-04T10:00:00Z"),
		(ResetReminderTiming.atReset, "2026-11-04T11:00:00Z"),
	])
	func schedulesOneRequestPerUpcomingResetAtAnAbsoluteInstant(
		timing: ResetReminderTiming, firstFire: String
	) async {
		let harness = Harness(scheduler: FakeScheduler(), now: now)
		defer { harness.cleanUp() }
		harness.settings.resetReminderRegions = [.global]
		harness.settings.resetReminderTiming = timing
		await harness.settle()

		let expected = (0..<7).map { date(firstFire).addingTimeInterval(Double($0) * 86_400) }
		#expect(fireDates(harness.scheduler, region: .global) == expected)
		#expect(
			harness.scheduler.pending.keys.sorted()
				== (4...10).map {
					String(format: "reset.global.2026-11-%02d.%d", $0, timing.leadMinutes ?? 0)
				})
	}

	@Test func changingTheTimingReplacesPendingRequests() async {
		let harness = Harness(scheduler: FakeScheduler(), now: now)
		defer { harness.cleanUp() }
		harness.settings.resetReminderRegions = [.global]
		harness.settings.resetReminderTiming = .minutes60
		await harness.settle()
		harness.settings.resetReminderTiming = .minutes30
		await harness.settle()

		let expected = (0..<7).map {
			date("2026-11-04T10:30:00Z").addingTimeInterval(Double($0) * 86_400)
		}
		#expect(fireDates(harness.scheduler, region: .global) == expected)
	}

	@Test func skipsAFireTimeThatAlreadyPassed() async {
		// The 1 hour reminder for today's 11:00 UTC reset was due at 10:00 UTC.
		let harness = Harness(scheduler: FakeScheduler(), now: date("2026-11-03T10:30:00Z"))
		defer { harness.cleanUp() }
		harness.settings.resetReminderRegions = [.global]
		harness.settings.resetReminderTiming = .minutes60
		await harness.settle()

		#expect(
			fireDates(harness.scheduler, region: .global).first == date("2026-11-04T10:00:00Z"))
		#expect(harness.scheduler.pending["reset.global.2026-11-03.60"] == nil)
	}

	@Test func turningOffRemovesEveryPendingRequest() async {
		let harness = Harness(scheduler: FakeScheduler(), now: now)
		defer { harness.cleanUp() }
		harness.settings.resetReminderRegions = [.global, .japan]
		harness.settings.resetReminderTiming = .minutes30
		await harness.settle()
		#expect(harness.scheduler.pending.count == 14)

		harness.settings.resetReminderTiming = .off
		await harness.settle()
		#expect(harness.scheduler.pending.isEmpty)
	}

	@Test func deselectingOrUninstallingAServerRemovesOnlyItsRequests() async {
		let harness = Harness(scheduler: FakeScheduler(), now: now)
		defer { harness.cleanUp() }
		harness.settings.resetReminderRegions = [.global, .japan]
		harness.settings.resetReminderTiming = .minutes30
		await harness.settle()

		harness.settings.resetReminderRegions = [.global]
		await harness.settle()
		#expect(fireDates(harness.scheduler, region: .japan).isEmpty)
		#expect(fireDates(harness.scheduler, region: .global).count == 7)

		harness.settings.resetReminderRegions = [.global, .japan]
		await harness.settle()
		harness.installed = [.japan]
		harness.controller.installedRegionsDidChange()
		await harness.settle()
		#expect(fireDates(harness.scheduler, region: .global).isEmpty)
		#expect(fireDates(harness.scheduler, region: .japan).count == 7)
	}

	@Test func planNeverExceedsTheRequestLimitAndKeepsTheSoonest() {
		let plan = ResetReminderPlan.notifications(
			now: now, timing: .atReset, regions: [.global, .japan, .korea], windowDays: 7, limit: 5)
		#expect(plan.count == 5)
		let dates = plan.compactMap { notification -> Date? in
			guard case .calendar(let components) = notification.trigger else { return nil }
			return components.date
		}
		#expect(dates == dates.sorted())
		// Japan and Korea reset at 19:00 UTC, so they come before Global's 11:00 UTC next day.
		#expect(Set(plan.map(\.identifier)).count == 5)
	}

	@Test func aSupersededRescheduleDoesNotApplyItsResult() async {
		let scheduler = FakeScheduler(holdsFirstRead: true)
		let harness = Harness(scheduler: scheduler, now: now)
		defer { harness.cleanUp() }
		harness.settings.resetReminderRegions = [.global]
		harness.settings.resetReminderTiming = .minutes60
		// The change above started a pass that now waits inside the first pending read.
		#expect(await scheduler.firstReadReached.wait(timeout: .seconds(10)))

		harness.settings.resetReminderRegions = [.japan]
		await harness.settle()
		scheduler.releaseFirstRead.fire()
		await harness.settle()

		#expect(fireDates(scheduler, region: .global).isEmpty)
		#expect(fireDates(scheduler, region: .japan).count == 7)
	}

	@Test func refusedPermissionTurnsTheReminderBackOff() async {
		let scheduler = FakeScheduler(authorization: .notDetermined, grantsRequest: false)
		let harness = Harness(scheduler: scheduler, now: now)
		defer { harness.cleanUp() }
		harness.settings.resetReminderTiming = .atReset
		await waitForCondition { harness.controller.isAccessDenied }

		#expect(harness.settings.resetReminderTiming == .off)
		#expect(scheduler.pending.isEmpty)
	}

	@Test func permissionIsAskedOnlyWhenTheUserTurnsTheReminderOn() async {
		let scheduler = FakeScheduler(authorization: .notDetermined)
		let harness = Harness(scheduler: scheduler, now: now)
		defer { harness.cleanUp() }
		await harness.settle()
		#expect(scheduler.requestCount == 0)

		harness.settings.resetReminderTiming = .minutes15
		await harness.settle()
		#expect(scheduler.requestCount == 1)
		#expect(harness.settings.resetReminderRegions == [.global])
		#expect(!scheduler.pending.isEmpty)
	}

	// Onboarding turns the reminder on before the first install finishes.
	@Test func aReminderChosenBeforeAnyInstallStartsOnceTheServerIsInstalled() async {
		let harness = Harness(scheduler: FakeScheduler(), now: now, installed: [])
		defer { harness.cleanUp() }
		harness.settings.resetReminderTiming = .atReset
		await harness.settle()
		#expect(harness.scheduler.pending.isEmpty)

		harness.installed = [.global]
		harness.controller.installedRegionsDidChange()
		await harness.settle()
		#expect(harness.settings.resetReminderRegions == [.global])
		#expect(fireDates(harness.scheduler, region: .global).count == 7)
	}
}
