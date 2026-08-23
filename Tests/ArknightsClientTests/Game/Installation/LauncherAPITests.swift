// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@Suite(.serialized)
struct LauncherAPITests {
	@Test
	func httpFailureCarriesOperationRegionEndpointAndStatusIntoDiagnostics() async throws {
		let session = makeSession()
		LauncherAPIURLProtocol.handler = { request in
			guard let url = request.url,
				let response = HTTPURLResponse(
					url: url,
					statusCode: 503,
					httpVersion: nil,
					headerFields: nil
				)
			else { fatalError("URLProtocol received an invalid HTTP request") }
			return (response, Data())
		}
		defer { LauncherAPIURLProtocol.handler = nil }
		let api = LauncherAPI(session: session)

		do {
			let _: GameConfiguration = try await api.gameConfiguration(region: .global)
			Issue.record("Expected the API request to fail")
		} catch {
			#expect(
				error.localizedDescription == LauncherError.invalidResponse.localizedDescription)
			let diagnostic = launcherDiagnosticDescription(for: error)
			#expect(diagnostic.contains("operation=game configuration"))
			#expect(diagnostic.contains("region=Global"))
			#expect(
				diagnostic.contains("endpoint=api-launcher-en.yo-star.com/api/launcher/game/config")
			)
			#expect(diagnostic.contains("status=503"))
		}
	}

	@Test
	func malformedPayloadRecordsTheDecodingPhaseWithoutExposingItInTheAlert() async throws {
		let session = makeSession()
		LauncherAPIURLProtocol.handler = { request in
			guard let url = request.url,
				let response = HTTPURLResponse(
					url: url,
					statusCode: 200,
					httpVersion: nil,
					headerFields: nil
				)
			else { fatalError("URLProtocol received an invalid HTTP request") }
			return (response, Data(#"{"code":200,"data":{}}"#.utf8))
		}
		defer { LauncherAPIURLProtocol.handler = nil }
		let api = LauncherAPI(session: session)

		do {
			let _: GameConfiguration = try await api.gameConfiguration(region: .japan)
			Issue.record("Expected payload decoding to fail")
		} catch {
			#expect(
				error.localizedDescription == LauncherError.invalidResponse.localizedDescription)
			let diagnostic = launcherDiagnosticDescription(for: error)
			#expect(diagnostic.contains("operation=game configuration"))
			#expect(diagnostic.contains("region=Japan"))
			#expect(diagnostic.contains("decoding failed"))
		}
	}

	@Test
	func configuredResponseLimitRejectsManifestBeforeDecoding() async throws {
		let session = makeSession()
		LauncherAPIURLProtocol.handler = { request in
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
		defer { LauncherAPIURLProtocol.handler = nil }
		let api = LauncherAPI(session: session, maximumManifestResponseBytes: 8)

		do {
			_ = try await api.manifestPayload(
				at: URL(string: "https://fixtures.invalid/manifest.json")!,
				region: .global
			)
			Issue.record("Expected the manifest response to exceed its configured limit")
		} catch {
			let diagnostic = launcherDiagnosticDescription(for: error)
			#expect(diagnostic.contains("operation=manifest download"))
			#expect(diagnostic.contains("response exceeded 8 bytes"))
		}
	}

	private func makeSession() -> URLSession {
		let configuration = URLSessionConfiguration.ephemeral
		configuration.protocolClasses = [LauncherAPIURLProtocol.self]
		return URLSession(configuration: configuration)
	}
}

private final class LauncherAPIURLProtocol: URLProtocol, @unchecked Sendable {
	nonisolated(unsafe) static var handler: ((URLRequest) -> (HTTPURLResponse, Data))?

	override class func canInit(with request: URLRequest) -> Bool { true }
	override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

	override func startLoading() {
		guard let handler = Self.handler else {
			client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
			return
		}
		let (response, data) = handler(request)
		client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
		client?.urlProtocol(self, didLoad: data)
		client?.urlProtocolDidFinishLoading(self)
	}

	override func stopLoading() {}
}
