// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsCustomization
import Foundation

@testable import ArknightsGameInstallation

actor ProgressRecorder {
	private var recordedUpdates: [DownloadProgress] = []

	func record(_ update: DownloadProgress) {
		recordedUpdates.append(update)
	}

	func updates() -> [DownloadProgress] {
		recordedUpdates
	}
}

struct InstallerFixture {
	let directory: URL
	let destination: URL
	let configuration: GameConfiguration
	let item: ManifestFile
	let source: String
	let baseURL: URL
	let installer: GameInstaller

	var partial: URL { destination.appendingPathExtension("part") }

	func remove() {
		try? FileManager.default.removeItem(at: directory)
	}
}

struct InstallerAPI: LauncherAPIProviding {
	let manifest: GameManifest
	let cdn: CDNConfiguration

	func gameConfiguration(region: GameRegion) async throws -> GameConfiguration {
		throw CancellationError()
	}
	func branding(region: GameRegion) async throws -> LauncherBranding { throw CancellationError() }
	func cdnConfiguration(region: GameRegion) async throws -> CDNConfiguration { cdn }
	func manifest(
		for configuration: GameConfiguration,
		region: GameRegion
	) async throws -> GameManifest { manifest }
}

final class StreamingURLProtocol: URLProtocol, @unchecked Sendable {
	nonisolated(unsafe) static var handler: ((URLRequest) -> (HTTPURLResponse, Data))?

	override class func canInit(with request: URLRequest) -> Bool { true }
	override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

	override func startLoading() {
		guard let result = Self.handler?(request) else {
			client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
			return
		}
		client?.urlProtocol(self, didReceive: result.0, cacheStoragePolicy: .notAllowed)
		for range in result.1.chunkRanges(size: 32 * 1_024) {
			client?.urlProtocol(self, didLoad: result.1.subdata(in: range))
		}
		client?.urlProtocolDidFinishLoading(self)
	}

	override func stopLoading() {}
}

extension Data {
	func chunkRanges(size: Int) -> [Range<Int>] {
		stride(from: 0, to: count, by: size).map { start in
			start..<Swift.min(start + size, count)
		}
	}
}
