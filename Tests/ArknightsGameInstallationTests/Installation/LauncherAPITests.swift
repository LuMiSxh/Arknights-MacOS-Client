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
			guard let url = request.url,
				let response = HTTPURLResponse(
					url: url,
					statusCode: 200,
					httpVersion: nil,
					headerFields: nil
				)
			else { fatalError("URLProtocol received an invalid HTTP request") }
			return (response, Data(repeating: 0x41, count: 9))
		}
		let api = LauncherAPI(session: route.session, maximumManifestResponseBytes: 8)

		do {
			_ = try await api.manifestPayload(
				at: URL(string: "https://local-cdn.yo-star.com/manifest.json")!,
				region: .global
			)
			Issue.record("Expected the manifest response to exceed its configured limit")
		} catch {
			let contextualError = try #require(error as? ContextualLauncherError)
			#expect(!contextualError.userMessage.isEmpty)
			let diagnostic = launcherDiagnosticDescription(for: error)
			#expect(diagnostic.contains("operation=manifest download"))
			#expect(diagnostic.contains("response exceeded 8 bytes"))
		}
	}
}
