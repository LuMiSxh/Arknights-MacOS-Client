// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@Test(arguments: [
	(GameRegion.global, "https://launcher-pkg-ark-en.yo-star.com", true),
	(.japan, "https://launcher-pkg-ark-jp.yo-star.com", true),
	(.korea, "https://launcher-pkg-ark-kr.yo-star.com", true),
	(.global, "https://cdn.example", false),
	(.china, "https://ak.hycdn.cn", true),
	(.chinaBilibili, "https://ak.hycdn.cn", true),
	(.taiwan, "https://ak-tw.hg-cdn.com", true),
	(.global, "http://launcher-pkg-ark-en.yo-star.com", false),
	(.korea, "https://user@launcher-pkg-ark-kr.yo-star.com", false),
	(.china, "https://evil.example", false),
	(.china, "http://ak.hycdn.cn", false),
	(.taiwan, "http://ak-tw.hg-cdn.com", false),
	(.taiwan, "https://evil.example", false),
	(.taiwan, "https://launcher.gryphline.com", false),
	(.taiwan, "https://ak-tw.hg-cdn.com:8443", false),
])
func installerAdmitsOnlyAllowedPublisherSources(
	region: GameRegion,
	source: String,
	allowed: Bool
) async throws {
	let root = FileManager.default.temporaryDirectory.appending(
		path: "installer-source-policy-\(UUID().uuidString)", directoryHint: .isDirectory
	)
	try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
	defer { try? FileManager.default.removeItem(at: root) }
	let configuration = URLSessionConfiguration.ephemeral
	configuration.protocolClasses = [DownloadAdmissionURLProtocol.self]
	let session = URLSession(configuration: configuration)
	defer { session.invalidateAndCancel() }
	let installer = GameInstaller(
		api: LauncherAPI(session: session),
		session: session,
		compatibilityManager: GameCompatibilityManager(active: [])
	)
	var checksum = CRC64()
	checksum.update(DownloadAdmissionURLProtocol.body)
	let item = ManifestFile(path: "nested/game.dat", hash: checksum.decimalString, size: "4")
	do {
		_ = try await withTestInstallDirectory(at: root) { installDirectory in
			try await installer.download(
				item,
				source: "game",
				baseURL: try #require(URL(string: source)),
				installDirectory: installDirectory,
				counter: ProgressCounter(totalBytes: 4, totalFiles: 1),
				progress: { _ in },
				region: region
			)
		}
		#expect(allowed)
	} catch LauncherError.invalidResponse {
		#expect(!allowed)
	}
	let destination = root.appending(path: item.path)
	#expect(FileManager.default.fileExists(atPath: destination.path) == allowed)
	if allowed {
		#expect(try Data(contentsOf: destination) == DownloadAdmissionURLProtocol.body)
	}
}

private final class DownloadAdmissionURLProtocol: URLProtocol, @unchecked Sendable {
	static let body = Data("game".utf8)

	override class func canInit(with request: URLRequest) -> Bool { true }

	override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

	override func startLoading() {
		guard let url = request.url,
			let response = HTTPURLResponse(
				url: url, statusCode: 200, httpVersion: "HTTP/1.1",
				headerFields: ["Content-Length": String(Self.body.count)]
			)
		else { return }
		client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
		client?.urlProtocol(self, didLoad: Self.body)
		client?.urlProtocolDidFinishLoading(self)
	}

	override func stopLoading() {}
}
