// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsInfrastructure
import ArknightsTestSupport
import Foundation
import Synchronization
import Testing

@testable import ArknightsPresence

struct DiscordPresenceSessionTests {
	@Test
	func staleSessionDoesNotClearNewerPresence() async throws {
		let directory = try TemporaryDirectory("DiscordPresenceSessionTests")
		defer { directory.remove() }
		let log = LauncherLog(fileURL: directory.url.appending(path: "launcher.log"))

		let connecting = Signal()
		let release = Signal()
		let first = FakeTransport(connectStarted: connecting, connectRelease: release)
		let second = FakeTransport()
		let transports = [first, second]
		let nextTransport = Mutex(0)

		let session = DiscordPresenceSession(
			clientID: "1539589207381770261",
			processIdentifier: 42,
			log: log,
			clock: ImmediateClock(),
			makeTransport: {
				let index = nextTransport.withLock { index in
					defer { index += 1 }
					return min(index, transports.count - 1)
				}
				return transports[index]
			}
		)

		let firstSession = UUID()
		let secondSession = UUID()
		let firstRequest = DiscordPresenceRequest(
			sessionID: firstSession,
			regionName: "Global",
			startedAt: Date(timeIntervalSince1970: 1_000)
		)
		let secondRequest = DiscordPresenceRequest(
			sessionID: secondSession,
			regionName: "Japan",
			startedAt: Date(timeIntervalSince1970: 2_000)
		)

		let firstApply = Task { await session.apply(.playing(firstRequest)) }
		await connecting.wait()
		let secondApply = Task { await session.apply(.playing(secondRequest)) }
		await second.activityRecorded.wait()
		await release.open()
		await firstApply.value
		await secondApply.value

		let state = await session.state
		let secondActivities = await second.activities
		let firstDisconnects = await first.disconnectCount
		let firstActivities = await first.activities
		#expect(state == .active(sessionID: secondSession))
		#expect(secondActivities.count == 1)
		#expect(secondActivities.last?.activity?.details == "Playing Arknights")
		#expect(secondActivities.last?.activity?.state == "Japan")
		#expect(secondActivities.last?.activity?.timestamps?.start == 2_000_000)
		#expect(
			secondActivities.last?.activity?.assets?.smallImage
				== SupportLinks.applicationIcon.absoluteString)
		#expect(secondActivities.last?.activity?.buttons?.first?.label == "Website")
		#expect(
			secondActivities.last?.activity?.buttons?.first?.url
				== SupportLinks.documentationRoot.absoluteString)
		#expect(firstDisconnects == 1)
		#expect(firstActivities.isEmpty)

		await session.apply(.idle)
		let finalState = await session.state
		let clearedActivities = await second.activities
		#expect(finalState == .idle)
		#expect(clearedActivities.last?.activity == nil)
	}
}

private struct ImmediateClock: Clock {
	typealias Duration = Swift.Duration
	typealias Instant = ContinuousClock.Instant

	var now: Instant { ContinuousClock().now }
	var minimumResolution: Duration { .zero }

	func sleep(until deadline: Instant, tolerance: Duration?) async throws {}
}

private actor Signal {
	private var isOpen = false
	private var waiters: [CheckedContinuation<Void, Never>] = []

	func open() {
		guard !isOpen else { return }
		isOpen = true
		let pending = waiters
		waiters.removeAll()
		for waiter in pending {
			waiter.resume()
		}
	}

	func wait() async {
		guard !isOpen else { return }
		await withCheckedContinuation { waiters.append($0) }
	}
}

private actor FakeTransport: DiscordIPCTransport {
	struct Call: Sendable {
		let activity: DiscordIPCActivity?
		let pid: Int32
	}

	private(set) var activities: [Call] = []
	private(set) var disconnectCount = 0
	let activityRecorded = Signal()

	private let connectStarted: Signal?
	private let connectRelease: Signal?
	private let closed = Signal()

	init(connectStarted: Signal? = nil, connectRelease: Signal? = nil) {
		self.connectStarted = connectStarted
		self.connectRelease = connectRelease
	}

	func connect(clientID: String) async throws {
		await connectStarted?.open()
		await connectRelease?.wait()
	}

	func setActivity(_ activity: DiscordIPCActivity?, pid: Int32) async throws {
		activities.append(Call(activity: activity, pid: pid))
		await activityRecorded.open()
	}

	func waitForDisconnect() async {
		await closed.wait()
	}

	func disconnect() async {
		disconnectCount += 1
		await closed.open()
	}
}
