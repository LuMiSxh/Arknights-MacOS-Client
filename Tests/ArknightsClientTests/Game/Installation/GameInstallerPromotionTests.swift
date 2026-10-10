// SPDX-License-Identifier: MPL-2.0

import Darwin
import Foundation
import Testing

@testable import ArknightsClient

@Suite(.serialized)
struct GameInstallerPromotionTests {
	@Test
	func promotionKeepsTheVerifiedInodeAndClearsCopiedACLs() async throws {
		let body = Data("verified-game".utf8)
		let fixture = try GameInstallerStreamingTests.makeFixture(
			body: body,
			protocolClass: PromotionURLProtocol.self
		)
		let parent = fixture.destination.deletingLastPathComponent()
		let movedParent = parent.deletingLastPathComponent().appending(path: "bin-moved")
		let outside = FileManager.default.temporaryDirectory.appending(
			path: "GameInstallerOutside-\(UUID().uuidString)",
			directoryHint: .isDirectory
		)
		let sentinel = Data("do-not-delete".utf8)
		defer {
			fixture.remove()
			try? FileManager.default.removeItem(at: outside)
		}
		try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
		PromotionURLProtocol.handler = { request in
			do {
				let chmod = Process()
				chmod.executableURL = URL(fileURLWithPath: "/bin/chmod")
				chmod.arguments = ["+a", "everyone allow read,write,append", fixture.partial.path]
				try chmod.run()
				chmod.waitUntilExit()
				guard chmod.terminationStatus == 0 else {
					Issue.record("Failed to add an ACL to the source partial")
					return (
						GameInstallerStreamingTests.response(url: request.url!, status: 200), body
					)
				}
				try FileManager.default.moveItem(at: parent, to: movedParent)
				try FileManager.default.createSymbolicLink(at: parent, withDestinationURL: outside)
				try FileManager.default.removeItem(at: movedParent.appending(path: "game.dat.part"))
				try sentinel.write(to: movedParent.appending(path: "game.dat.part"))
			} catch {
				Issue.record("Failed to substitute the partial during its request: \(error)")
			}
			return (GameInstallerStreamingTests.response(url: request.url!, status: 200), body)
		}
		defer { PromotionURLProtocol.handler = nil }

		_ = try await fixture.installer.install(
			configuration: fixture.configuration,
			region: .global,
			into: fixture.directory,
			progress: { _ in }
		)

		#expect(try Data(contentsOf: movedParent.appending(path: "game.dat")) == body)
		#expect(try Data(contentsOf: movedParent.appending(path: "game.dat.part")) == sentinel)
		#expect(try FileManager.default.contentsOfDirectory(atPath: outside.path).isEmpty)
		try await withTestInstallDirectory(at: fixture.directory) { installed in
			let installedFile = try installed.file(at: "bin-moved/game.dat")
			let descriptor = try installedFile.open(flags: O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
			defer { _ = close(descriptor) }
			let acl = acl_get_fd_np(descriptor, ACL_TYPE_EXTENDED)
			#expect(acl == nil)
			#expect(errno == ENOENT)
		}
	}
}

private final class PromotionURLProtocol: URLProtocol, @unchecked Sendable {
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
