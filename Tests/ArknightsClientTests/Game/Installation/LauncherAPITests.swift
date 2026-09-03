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
			let contextualError = try #require(error as? ContextualLauncherError)
			#expect(!contextualError.userMessage.isEmpty)
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
			let contextualError = try #require(error as? ContextualLauncherError)
			#expect(contextualError.userMessage != contextualError.diagnosticDescription)
			let diagnostic = launcherDiagnosticDescription(for: error)
			#expect(diagnostic.contains("operation=game configuration"))
			#expect(diagnostic.contains("region=Japan"))
			#expect(diagnostic.contains("decoding failed"))
		}
	}

	@Test
	func transportFailureUsesAContextualLauncherError() async throws {
		let configuration = URLSessionConfiguration.ephemeral
		configuration.protocolClasses = [FailingLauncherAPIURLProtocol.self]
		let api = LauncherAPI(session: URLSession(configuration: configuration))

		do {
			let _: GameConfiguration = try await api.gameConfiguration(region: .global)
			Issue.record("Expected the API request to fail")
		} catch {
			let contextualError = try #require(error as? ContextualLauncherError)
			#expect(!contextualError.userMessage.isEmpty)
		}
	}

	@Test
	func bilibiliUsesItsHypergryphGameChannelWithoutASeparateLauncher() async throws {
		let session = makeSession()
		var requestBody: Data?
		LauncherAPIURLProtocol.handler = { request in
			requestBody = bodyData(for: request)
			let response = HTTPURLResponse(
				url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
			return (
				response,
				Data(
					#"{"proxy_rsps":[{"kind":"get_latest_game","get_latest_game_rsp":{"version":"76.0.0","pkg":{"file_path":"https://ak.hycdn.cn/GzD1CpaWgmSq1wew/76.0/update/2/2/Windows/files","total_size":"1"}}}]}"#
						.utf8
				)
			)
		}
		defer { LauncherAPIURLProtocol.handler = nil }
		let region = try JSONDecoder().decode(
			GameRegion.self,
			from: Data(#""chinaBilibili""#.utf8)
		)

		_ = try await LauncherAPI(session: session).gameConfiguration(region: region)

		let body = try #require(requestBody)
		let root = try #require(
			JSONSerialization.jsonObject(with: body) as? [String: Any])
		let requests = try #require(root["proxy_reqs"] as? [[String: Any]])
		let latest = try #require(requests.first?["get_latest_game_req"] as? [String: Any])
		#expect(latest["channel"] as? String == "2")
		#expect(latest["sub_channel"] as? String == "2")
		#expect(latest["launcher_appcode"] as? String == "")
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
			let contextualError = try #require(error as? ContextualLauncherError)
			#expect(!contextualError.userMessage.isEmpty)
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

private func bodyData(for request: URLRequest) -> Data? {
	if let body = request.httpBody { return body }
	guard let stream = request.httpBodyStream else { return nil }
	stream.open()
	defer { stream.close() }
	var data = Data()
	var buffer = [UInt8](repeating: 0, count: 1_024)
	while stream.hasBytesAvailable {
		let count = stream.read(&buffer, maxLength: buffer.count)
		guard count >= 0 else { return nil }
		if count == 0 { break }
		data.append(contentsOf: buffer.prefix(count))
	}
	return data
}

private final class FailingLauncherAPIURLProtocol: URLProtocol, @unchecked Sendable {
	override class func canInit(with request: URLRequest) -> Bool { true }
	override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

	override func startLoading() {
		client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
	}

	override func stopLoading() {}
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
