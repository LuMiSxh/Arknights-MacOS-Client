// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsInfrastructure
import ArknightsTestSupport
import CoreGraphics
import Foundation
import Synchronization
import Testing

@testable import ArknightsGameRuntime

func makeTestImage() -> CGImage {
	let context = CGContext(
		data: nil, width: 4, height: 4, bitsPerComponent: 8, bytesPerRow: 0,
		space: CGColorSpaceCreateDeviceRGB(),
		bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
	context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
	context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
	return context.makeImage()!
}

private struct ClosureCapturer: WindowImageCapturing {
	let capture: @Sendable (Int32) async throws -> CGImage
	func captureGameWindow(processIdentifier: Int32) async throws -> CGImage {
		try await capture(processIdentifier)
	}
}

private final class RecordingScheduler: NotificationScheduling {
	private let added = Mutex<[LocalNotification]>([])
	var notifications: [LocalNotification] { added.withLock { $0 } }
	func authorization() async -> NotificationAuthorization { .authorized }
	func requestAuthorization() async throws -> Bool { true }
	func pendingIdentifiers() async -> Set<String> { [] }
	func add(_ notification: LocalNotification) async throws {
		added.withLock { $0.append(notification) }
	}
	func removePending(identifiers: Set<String>) {}
}

@MainActor
private struct Fixture {
	let temporary: TemporaryDirectory
	let suiteName: String
	let defaults: UserDefaults
	let lifecycle = makeLifecycleStore()
	let scheduler = RecordingScheduler()
	let paths: AppPaths
	let controller: GameScreenshotController
	let lease: ActivityLease
	let sessionID = UUID()

	init(endSessionDuringCapture: Bool) throws {
		temporary = try TemporaryDirectory("GameScreenshotControllerTests")
		(defaults, suiteName) = makeIsolatedDefaults("GameScreenshotControllerTests")
		paths = AppPaths(
			applicationSupportDirectory: temporary.url.appending(path: "Support"),
			cachesDirectory: temporary.url.appending(path: "Caches"),
			libraryDirectory: temporary.url.appending(path: "Library"),
			picturesDirectory: temporary.url.appending(path: "Pictures"))
		let lifecycle = self.lifecycle
		let sessionID = self.sessionID
		lease = lifecycle.begin(.runningGame(sessionID: sessionID, processIdentifier: 42))!
		let lease = self.lease
		controller = GameScreenshotController(
			lifecycle: lifecycle,
			settings: LauncherPreferencesController(
				store: LauncherPreferencesStore(defaults: defaults)),
			paths: paths,
			capturer: ClosureCapturer { _ in
				if endSessionDuringCapture {
					await MainActor.run { _ = lifecycle.end(lease) }
				}
				return makeTestImage()
			},
			permission: ScreenCapturePermission(isGranted: { true }, request: {}),
			scheduler: scheduler,
			region: { .global },
			playSound: {})
	}

	func remove() {
		defaults.removePersistentDomain(forName: suiteName)
		temporary.remove()
	}

	var savedFiles: [String] {
		(try? FileManager.default.contentsOfDirectory(atPath: paths.screenshotsDirectory.path))
			?? []
	}
}

@MainActor
@Test(arguments: [false, true])
private func aGameSessionThatEndsDuringCaptureLeavesNoFileAndNoFailure(
	sessionEnds: Bool
) async throws {
	let fixture = try Fixture(endSessionDuringCapture: sessionEnds)
	defer { fixture.remove() }

	await fixture.controller.takeScreenshot()?.value

	if sessionEnds {
		#expect(fixture.savedFiles.isEmpty)
		#expect(fixture.scheduler.notifications.isEmpty)
	} else {
		#expect(fixture.savedFiles.count == 1)
		#expect(fixture.scheduler.notifications.count == 1)
	}
}
