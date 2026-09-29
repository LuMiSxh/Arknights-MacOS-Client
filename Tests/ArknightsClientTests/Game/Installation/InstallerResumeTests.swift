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
			let installDirectory = try InstallerInstallDirectory(at: fixture.directory)
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

	@Test
	func onlyStrongEntityTagsAreUsedForIfRange() {
		#expect(
			InstallerResumeMetadata(
				manifestHash: "hash",
				entityTag: "W/\"weak\"",
				lastModified: "Mon, 01 Jan 2024 00:00:00 GMT"
			).ifRangeValue == nil
		)
		#expect(
			InstallerResumeMetadata(
				manifestHash: "hash",
				entityTag: "\"strong\"",
				lastModified: "Mon, 01 Jan 2024 00:00:00 GMT"
			).ifRangeValue == "\"strong\""
		)
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
