// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsInfrastructure
import ArknightsTestSupport
import CoreGraphics
import Foundation
import Synchronization
import Testing

@testable import ArknightsGameRuntime

private final class FakeHotKey: HotKeyRegistration, Sendable {
	let isCancelled = Mutex(false)
	func cancel() { isCancelled.withLock { $0 = true } }
}

private final class Registrations: Sendable {
	let items = Mutex<[FakeHotKey]>([])
}

private final class Counter: Sendable {
	let value = Mutex(0)
	func increment() { value.withLock { $0 += 1 } }
}

private struct BlockingCapturer: WindowImageCapturing {
	let calls: Counter
	let gate: AsyncStream<Void>
	func captureGameWindow(processIdentifier: Int32) async throws -> CGImage {
		calls.increment()
		for await _ in gate { break }
		return makeTestImage()
	}
}

private struct NoNotifications: NotificationScheduling {
	func authorization() async -> NotificationAuthorization { .denied }
	func requestAuthorization() async throws -> Bool { false }
	func pendingIdentifiers() async -> Set<String> { [] }
	func add(_ notification: LocalNotification) async throws {}
	func removePending(identifiers: Set<String>) {}
}

@MainActor
private final class Fixture {
	let temporary: TemporaryDirectory
	let suiteName: String
	let defaults: UserDefaults
	let lifecycle = makeLifecycleStore()
	let settings: LauncherPreferencesController
	let controller: GameScreenshotController
	let registrations = Registrations()
	let calls = Counter()
	let gateContinuation: AsyncStream<Void>.Continuation
	var lease: ActivityLease?

	init(granted: Bool, shortcut: ScreenshotShortcut) throws {
		temporary = try TemporaryDirectory("ScreenshotHotKeyLifecycleTests")
		(defaults, suiteName) = makeIsolatedDefaults("ScreenshotHotKeyLifecycleTests")
		settings = LauncherPreferencesController(
			store: LauncherPreferencesStore(defaults: defaults))
		settings.screenshotShortcut = shortcut
		let registrations = self.registrations
		let (gate, continuation) = AsyncStream<Void>.makeStream(
			bufferingPolicy: .bufferingNewest(1))
		gateContinuation = continuation
		controller = GameScreenshotController(
			lifecycle: lifecycle,
			settings: settings,
			paths: AppPaths(
				applicationSupportDirectory: temporary.url.appending(path: "Support"),
				cachesDirectory: temporary.url.appending(path: "Caches"),
				libraryDirectory: temporary.url.appending(path: "Library"),
				picturesDirectory: temporary.url.appending(path: "Pictures")),
			capturer: BlockingCapturer(calls: calls, gate: gate),
			permission: ScreenCapturePermission(isGranted: { granted }, request: {}),
			scheduler: NoNotifications(),
			region: { .global },
			makeHotKey: { _, _ in
				let hotKey = FakeHotKey()
				registrations.items.withLock { $0.append(hotKey) }
				return hotKey
			},
			playSound: {})
		controller.start()
	}

	func startGame() {
		lease = lifecycle.begin(.runningGame(sessionID: UUID(), processIdentifier: 42))
	}

	func endGame() {
		if let lease { lifecycle.end(lease) }
	}

	var liveRegistrations: Int {
		registrations.items.withLock { $0.filter { !$0.isCancelled.withLock { $0 } }.count }
	}

	func remove() {
		gateContinuation.finish()
		defaults.removePersistentDomain(forName: suiteName)
		temporary.remove()
	}
}

private struct RegistrationCase: Sendable, CustomTestStringConvertible {
	let gameRuns: Bool
	let shortcut: ScreenshotShortcut
	let granted: Bool
	let registers: Bool
	var testDescription: String { "game \(gameRuns), \(shortcut), granted \(granted)" }
}

@MainActor
@Test(
	arguments: [
		RegistrationCase(gameRuns: true, shortcut: .f13, granted: true, registers: true),
		RegistrationCase(gameRuns: false, shortcut: .f13, granted: true, registers: false),
		RegistrationCase(gameRuns: true, shortcut: .off, granted: true, registers: false),
		RegistrationCase(gameRuns: true, shortcut: .f13, granted: false, registers: false),
	])
private func theShortcutRegistersOnlyWhileTheGameRunsAndAccessExists(
	_ testCase: RegistrationCase
)
	throws
{
	let fixture = try Fixture(granted: testCase.granted, shortcut: testCase.shortcut)
	defer { fixture.remove() }

	if testCase.gameRuns { fixture.startGame() }

	#expect(fixture.liveRegistrations == (testCase.registers ? 1 : 0))
	let denied = testCase.gameRuns && !testCase.granted && testCase.shortcut != .off
	#expect(fixture.controller.isPermissionDenied == denied)
	// A missing permission also turns the stored shortcut off.
	#expect(fixture.settings.screenshotShortcut == (denied ? .off : testCase.shortcut))
}

@MainActor
@Test
private func theShortcutIsReleasedWhenTheGameEndsOrTheShortcutTurnsOff() throws {
	let fixture = try Fixture(granted: true, shortcut: .controlOptionS)
	defer { fixture.remove() }

	fixture.startGame()
	#expect(fixture.liveRegistrations == 1)
	fixture.endGame()
	#expect(fixture.liveRegistrations == 0)

	fixture.startGame()
	#expect(fixture.liveRegistrations == 1)
	fixture.settings.screenshotShortcut = .off
	#expect(fixture.liveRegistrations == 0)
}

@MainActor
@Test
private func choosingAShortcutWithoutAccessTurnsItOffAndShowsThePermissionRow() throws {
	let fixture = try Fixture(granted: false, shortcut: .off)
	defer { fixture.remove() }

	fixture.settings.screenshotShortcut = .f13

	#expect(fixture.settings.screenshotShortcut == .off)
	#expect(fixture.controller.isPermissionDenied)
}

@MainActor
@Test
private func aPressWhileACaptureRunsIsIgnored() async throws {
	let fixture = try Fixture(granted: true, shortcut: .off)
	defer { fixture.remove() }
	fixture.startGame()

	let first = fixture.controller.takeScreenshot()
	let second = fixture.controller.takeScreenshot()
	fixture.gateContinuation.yield()
	await first?.value

	#expect(first != nil)
	#expect(second == nil)
	#expect(fixture.calls.value.withLock { $0 } == 1)
}
