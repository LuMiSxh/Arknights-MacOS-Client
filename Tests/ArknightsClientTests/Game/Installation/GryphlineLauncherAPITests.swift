// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@Suite(.serialized)
struct GryphlineLauncherAPITests {
	@Test
	func gameConfigurationUsesTaiwanMetadataAndRequestContract() async throws {
		let session = makeSession()
		var request: URLRequest?
		GryphlineURLProtocol.handler = { receivedRequest in
			request = receivedRequest
			return (
				HTTPURLResponse(
					url: receivedRequest.url!,
					statusCode: 200,
					httpVersion: nil,
					headerFields: nil
				)!,
				Data(Self.latestGameResponse.utf8)
			)
		}
		defer { GryphlineURLProtocol.handler = nil }

		let api = GryphlineLauncherAPI(session: session)
		let configuration = try await api.gameConfiguration()
		let cdn = try await api.cdnConfiguration()

		#expect(configuration.gameLowestVersion == "72.0.0")
		#expect(configuration.gameLatestVersion == "72.0.0")
		#expect(configuration.gameStartExeName == "Arknights.exe")
		#expect(configuration.decompressionSize == "41163MB")
		#expect(cdn.primaryCdn == URL(string: "https://ak-tw.hg-cdn.com")!)
		#expect(cdn.backUpCdn == cdn.primaryCdn)
		#expect(
			configuration.gameLatestFilePath
				== "https://ak-tw.hg-cdn.com/uiCaUeGDB2htwXSv/72.0/update/6/6/Windows/72.0.0_WGEc8hYsFKsF7NMt/files"
		)

		let body = try #require(request.flatMap(bodyData))
		let root = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
		let requests = try #require(root["proxy_reqs"] as? [[String: Any]])
		let latest = try #require(requests.first?["get_latest_game_req"] as? [String: Any])
		#expect(request?.httpMethod == "POST")
		#expect(request?.url?.host == "launcher.gryphline.com")
		#expect(request?.url?.path == "/api/proxy/batch_proxy")
		#expect(root["seq"] as? String == "5")
		#expect(requests.first?["kind"] as? String == "get_latest_game")
		#expect(latest["appcode"] as? String == "uiCaUeGDB2htwXSv")
		#expect(latest["channel"] as? String == "6")
		#expect(latest["sub_channel"] as? String == "6")
		#expect(latest["launcher_appcode"] as? String == "TiaytKBUIEdoEwRT")
	}

	@Test
	func brandingUsesTraditionalChineseWebMetadataAndTrustedAssetHost() async throws {
		let session = makeSession()
		var request: URLRequest?
		GryphlineURLProtocol.handler = { receivedRequest in
			request = receivedRequest
			return (
				HTTPURLResponse(
					url: receivedRequest.url!,
					statusCode: 200,
					httpVersion: nil,
					headerFields: nil
				)!,
				Data(Self.brandingResponse.utf8)
			)
		}
		defer { GryphlineURLProtocol.handler = nil }

		let branding = try await GryphlineLauncherAPI(session: session).branding()

		#expect(
			branding.launcherBackgroundImage?.absoluteString
				== "https://gl-utils-public.hg-cdn.com/hg-utils/prod/uiCaUeGDB2htwXSv/background.png"
		)
		#expect(branding.launcherBackgroundImageCRC64 == "b9673efd93f60617746541e2bc92f20f")
		let body = try #require(request.flatMap(bodyData))
		let root = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
		let requests = try #require(root["proxy_reqs"] as? [[String: Any]])
		let background = try #require(requests.first?["get_main_bg_image_req"] as? [String: Any])
		#expect(request?.httpMethod == "POST")
		#expect(request?.url?.path == "/api/proxy/web/batch_proxy")
		#expect(root["seq"] as? String == "5")
		#expect(requests.first?["kind"] as? String == "get_main_bg_image")
		#expect(background["appcode"] as? String == "uiCaUeGDB2htwXSv")
		#expect(background["channel"] as? String == "6")
		#expect(background["sub_channel"] as? String == "6")
		#expect(background["language"] as? String == "zh-tw")
		#expect(background["platform"] as? String == "Windows")
		#expect(background["source"] as? String == "launcher")
	}

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

		let manifest = try await GryphlineLauncherAPI(session: session).manifest(
			for: configuration
		)

		#expect(
			manifest.source
				== "uiCaUeGDB2htwXSv/72.0/update/6/6/Windows/"
				+ "72.0.0_WGEc8hYsFKsF7NMt/files"
		)
		#expect(manifest.file.map(\.path) == ["Arknights.exe", "AntiCheatExpert/ACE-BASE.sys"])
		#expect(manifest.file.map(\.size) == ["827864", "12"])
	}

	@Test
	func rejectsLatestGameMetadataFromAnUntrustedHost() async throws {
		let session = makeSession()
		GryphlineURLProtocol.handler = { receivedRequest in
			let response = Self.latestGameResponse.replacingOccurrences(
				of: "https://ak-tw.hg-cdn.com",
				with: "https://evil.example"
			)
			return (
				HTTPURLResponse(
					url: receivedRequest.url!,
					statusCode: 200,
					httpVersion: nil,
					headerFields: nil
				)!,
				Data(response.utf8)
			)
		}
		defer { GryphlineURLProtocol.handler = nil }

		await #expect(throws: LauncherError.self) {
			try await GryphlineLauncherAPI(session: session).gameConfiguration()
		}
	}

	private func makeSession() -> URLSession {
		let configuration = URLSessionConfiguration.ephemeral
		configuration.protocolClasses = [GryphlineURLProtocol.self]
		return URLSession(configuration: configuration)
	}

	private static let latestGameResponse = """
		{
		  "proxy_rsps": [{
		    "kind": "get_latest_game",
		    "get_latest_game_rsp": {
		      "action": 1,
		      "version": "72.0.0",
		      "request_version": "",
		      "pkg": {
		        "total_size": "41162979241",
		        "file_path": "https://ak-tw.hg-cdn.com/uiCaUeGDB2htwXSv/72.0/update/6/6/Windows/72.0.0_WGEc8hYsFKsF7NMt/files",
		        "game_files_md5": "d939e6ea894302de36a90f7947a3c894"
		      },
		      "client_version": "36.7.21"
		    }
		  }]
		}
		"""

	private static let brandingResponse = """
		{
		  "proxy_rsps": [{
		    "kind": "get_main_bg_image",
		    "get_main_bg_image_rsp": {
		      "data_version": "",
		      "main_bg_image": {
		        "url": "https://gl-utils-public.hg-cdn.com/hg-utils/prod/uiCaUeGDB2htwXSv/background.png",
		        "md5": "b9673efd93f60617746541e2bc92f20f",
		        "video_url": ""
		      }
		    }
		  }]
		}
		"""

	private static let encryptedManifestFixture =
		"j4mDUJTXDbc0VaqHClYMGJ57k6MSh6Xn1zTLx9zcwwfQsl6WiskAgwagWWbADaR3"
		+ "1y0i9PyPu6PbRSDrBvOFvuwYiKRw6YaO6734PoXozZ05/WlwbrkDjOeHZaTMDBgqH"
		+ "mSoeediyLVcKCL7ZzZi9M7yCIDjp57z1W3Qnhihk8+SWLarnydFiXP912R3myAjc"
		+ "VkaGATyDxYt5YwqCbfulw4dwSuzwrRVd6NU1WXtGuQ="
}

private func bodyData(for request: URLRequest?) -> Data? {
	guard let request else { return nil }
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
