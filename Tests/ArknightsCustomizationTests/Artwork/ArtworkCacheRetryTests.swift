// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsCustomization

struct ArtworkCacheRetryTests {
	private static let pngData = Data(
		base64Encoded:
			"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Y9Zf9sAAAAASUVORK5CYII="
	)!
	private let branding = LauncherBranding(
		launcherBackgroundImage: URL(string: "https://ak.hycdn.cn/background.png"),
		launcherBackgroundImageCRC64: "retry",
		privacyPolicy: nil,
		userAgreement: nil,
		noticePopOpen: false,
		noticeContent: nil
	)

	@Test func aTransientFailureIsRetriedAfterOneWaitAndAppliesTheArtwork() async throws {
		let temporary = try TemporaryDirectory("ArtworkCacheRetryTests")
		defer { temporary.remove() }
		let route = StubURLProtocol.Route()
		route.handler = { request in
			if route.requestCount == 1 { throw URLError(.cannotConnectToHost) }
			return (
				HTTPURLResponse(
					url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
				Self.pngData
			)
		}
		let clock = RecordingClock()
		let cache = ArtworkCache(session: route.session, directory: temporary.url, clock: clock)

		let data = try await cache.imageData(for: branding, region: .china)

		#expect(data != nil)
		#expect(route.requestCount == 2)
		#expect(clock.sleeps.map(\.duration) == [AppConstants.Artwork.transientRetryBaseDelay])
	}

	@Test func cancellingDuringTheWaitStopsTheRetry() async throws {
		let temporary = try TemporaryDirectory("ArtworkCacheRetryTests")
		defer { temporary.remove() }
		let started = Signal()
		let route = StubURLProtocol.Route()
		route.handler = { _ in
			started.fire()
			throw URLError(.cannotConnectToHost)
		}
		let cache = ArtworkCache(
			session: route.session, directory: temporary.url, clock: ParkedClock())
		let download = Task { try await cache.imageData(for: branding, region: .china) }
		#expect(await started.wait(timeout: .seconds(10)))

		download.cancel()

		await #expect(throws: CancellationError.self) { _ = try await download.value }
		#expect(route.requestCount == 1)
	}
}
