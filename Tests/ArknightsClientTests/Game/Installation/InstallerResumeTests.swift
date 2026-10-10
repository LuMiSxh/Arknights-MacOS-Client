// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@Suite(.serialized)
struct InstallerResumeTests {
	@Test
	func rangeResumeAcceptsMatchingETagWhenLastModifiedIsOmitted() async throws {
		let body = Data("game".utf8)
		let fixture = try GameInstallerStreamingTests.makeFixture(
			body: body,
			protocolClass: ResumeURLProtocol.self
		)
		defer { fixture.remove() }
		try Data(body.prefix(2)).write(to: fixture.partial)
		do {
			try await withTestInstallDirectory(at: fixture.directory) { installDirectory in
				let staging = try installDirectory.stagingDirectory(
					named: AppConstants.Game.installerStagingDirectoryName
				)
				let metadata = fixture.installer.resumeMetadataFile(
					for: fixture.item.path,
					in: staging
				)
				try fixture.installer.writeResumeMetadata(
					InstallerResumeMetadata(
						manifestHash: fixture.item.hash,
						entityTag: "\"v1\"",
						lastModified: "Mon, 01 Jan 2024 00:00:00 GMT"
					),
					to: metadata
				)
			}
		}

		var requestCount = 0
		ResumeURLProtocol.handler = { request in
			requestCount += 1
			#expect(request.value(forHTTPHeaderField: "Range") == "bytes=2-")
			#expect(request.value(forHTTPHeaderField: "If-Range") == "\"v1\"")
			return (
				GameInstallerStreamingTests.response(
					url: request.url!,
					status: 206,
					headers: [
						"Content-Range": "bytes 2-3/4",
						"ETag": "\"v1\"",
					]
				),
				Data(body.dropFirst(2))
			)
		}
		defer { ResumeURLProtocol.handler = nil }

		_ = try await fixture.installer.install(
			configuration: fixture.configuration,
			region: .global,
			into: fixture.directory,
			progress: { _ in }
		)

		#expect(requestCount == 1)
		#expect(try Data(contentsOf: fixture.destination) == body)
	}

	@Test(arguments: [
		(
			"release validators",
			[
				"ETag": "\"930F52526F9F34822294B1B0F8AD5990\"",
				"Last-Modified": "Wed, 12 Aug 2026 10:30:34 GMT",
			],
			Optional("\"930F52526F9F34822294B1B0F8AD5990\""),
			Optional("Wed, 12 Aug 2026 10:30:34 GMT"),
			Optional("\"930F52526F9F34822294B1B0F8AD5990\""),
			false
		),
		(
			"weak ETag with Last-Modified",
			["ETag": "W/\"weak\"", "Last-Modified": "Wed, 12 Aug 2026 10:30:34 GMT"],
			Optional("W/\"weak\""),
			Optional("Wed, 12 Aug 2026 10:30:34 GMT"),
			nil,
			false
		),
		(
			"Last-Modified only", ["Last-Modified": "Wed, 12 Aug 2026 10:30:34 GMT"], nil,
			Optional("Wed, 12 Aug 2026 10:30:34 GMT"), nil, false
		),
		("no validators", [:], nil, nil, nil, false),
		("empty ETag", ["ETag": ""], nil, nil, nil, true),
		("oversized ETag", ["ETag": String(repeating: "x", count: 4_097)], nil, nil, nil, true),
		(
			"control in Last-Modified", ["Last-Modified": "Wed, 12 Aug\u{0085} 2026"], nil, nil,
			nil, true
		),
	])
	func resumeMetadataValidatesResponseHeaders(
		scenario: String,
		headers: [String: String],
		expectedEntityTag: String?,
		expectedLastModified: String?,
		expectedIfRange: String?,
		rejectsResponse: Bool
	) throws {
		let response = GameInstallerStreamingTests.response(
			url: URL(string: "https://cdn.example/game.dat")!,
			status: 206,
			headers: headers
		)
		if rejectsResponse {
			#expect(throws: LauncherError.self) {
				try GameInstaller.resumeMetadata(from: response, manifestHash: "fixture")
			}
			return
		}

		let metadata = try GameInstaller.resumeMetadata(from: response, manifestHash: "fixture")
		let comment = Comment(rawValue: scenario)
		#expect(metadata.manifestHash == "fixture", comment)
		#expect(metadata.entityTag == expectedEntityTag, comment)
		#expect(metadata.lastModified == expectedLastModified, comment)
		#expect(metadata.ifRangeValue == expectedIfRange, comment)
	}
}

private final class ResumeURLProtocol: URLProtocol, @unchecked Sendable {
	nonisolated(unsafe) static var handler: ((URLRequest) -> (HTTPURLResponse, Data))?

	override class func canInit(with request: URLRequest) -> Bool { true }
	override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

	override func startLoading() {
		guard let result = Self.handler?(request) else {
			client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
			return
		}
		client?.urlProtocol(self, didReceive: result.0, cacheStoragePolicy: .notAllowed)
		client?.urlProtocol(self, didLoad: result.1)
		client?.urlProtocolDidFinishLoading(self)
	}

	override func stopLoading() {}
}
