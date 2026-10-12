// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsCore
@testable import ArknightsGameInstallation

@Suite(.serialized)
struct GryphlineLauncherAPITests {
	private static let profile = GameRegion.taiwan.hypergryphProfile!

	@Test
	func manifestDecryptsEncryptedJSONLinesAndPreservesSafeSource() async throws {
		let session = makeSession()
		GryphlineURLProtocol.handler = { receivedRequest in
			#expect(receivedRequest.url?.path.hasSuffix("/files/game_files") == true)
			return (
				HTTPURLResponse(
					url: receivedRequest.url!,
					statusCode: 200,
					httpVersion: nil,
					headerFields: nil
				)!,
				Data(base64Encoded: Self.encryptedManifestFixture)!
			)
		}
		defer { GryphlineURLProtocol.handler = nil }

		let configuration = GameConfiguration(
			gameLowestVersion: "72.0.0",
			gameLatestVersion: "72.0.0",
			gameLatestFilePath:
				"https://ak-tw.hg-cdn.com/uiCaUeGDB2htwXSv/72.0/update/6/6/Windows/"
				+ "72.0.0_WGEc8hYsFKsF7NMt/files",
			gameStartExeName: "Arknights.exe",
			gameStartParams: [],
			gameUninstallScript: "",
			decompressionSize: "41163MB"
		)

		let manifest = try await HypergryphLauncherAPI(session: session).manifest(
			for: configuration,
			profile: Self.profile
		)

		#expect(
			manifest.source
				== "uiCaUeGDB2htwXSv/72.0/update/6/6/Windows/"
				+ "72.0.0_WGEc8hYsFKsF7NMt/files"
		)
		#expect(manifest.file.map(\.path) == ["Arknights.exe", "AntiCheatExpert/ACE-BASE.sys"])
		#expect(manifest.file.map(\.size) == ["827864", "12"])
	}

	private func makeSession() -> URLSession {
		let configuration = URLSessionConfiguration.ephemeral
		configuration.protocolClasses = [GryphlineURLProtocol.self]
		return URLSession(configuration: configuration)
	}

	private static let encryptedManifestFixture =
		"j4mDUJTXDbc0VaqHClYMGJ57k6MSh6Xn1zTLx9zcwwfQsl6WiskAgwagWWbADaR3"
		+ "1y0i9PyPu6PbRSDrBvOFvuwYiKRw6YaO6734PoXozZ05/WlwbrkDjOeHZaTMDBgqH"
		+ "mSoeediyLVcKCL7ZzZi9M7yCIDjp57z1W3Qnhihk8+SWLarnydFiXP912R3myAjc"
		+ "VkaGATyDxYt5YwqCbfulw4dwSuzwrRVd6NU1WXtGuQ="
}

private final class GryphlineURLProtocol: URLProtocol, @unchecked Sendable {
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
