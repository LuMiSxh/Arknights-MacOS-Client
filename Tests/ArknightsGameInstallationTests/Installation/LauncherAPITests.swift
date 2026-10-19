// SPDX-License-Identifier: MPL-2.0

import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsCore
@testable import ArknightsGameInstallation

@Suite(.serialized)
struct LauncherAPITests {
	@Test
	func configuredResponseLimitRejectsManifestBeforeDecoding() async throws {
		let route = StubURLProtocol.Route()
		route.handler = { request in
			(
				makeHTTPResponse(url: request.url!, status: 200),
				Data(repeating: 0x41, count: 9)
			)
		}
		let api = LauncherAPI(session: route.session, maximumManifestResponseBytes: 8)

		await #expect(throws: ContextualLauncherError.self) {
			_ = try await api.manifestPayload(
				at: URL(string: "https://local-cdn.yo-star.com/manifest.json")!,
				region: .global
			)
		}
	}
}
