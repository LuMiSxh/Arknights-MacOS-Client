// SPDX-License-Identifier: MPL-2.0

import Darwin
import Foundation
import Testing

@testable import ArknightsClient

@Suite(.serialized)
struct GameInstallerReuseTests {
	private static let body = Data((0..<4_096).map { UInt8($0 % 251) })

	@Test
	func matchingDonorFileIsClonedInsteadOfDownloaded() async throws {
		let world = try ReuseWorld()
		defer { world.remove() }
		let donor = try world.makeDonor(body: Self.body)
		let before = try FileSnapshot(donor.file)
		let recorder = ProgressRecorder()

		let result = try await world.install(donors: [donor.directory]) {
			await recorder.record($0)
		}

		#expect(ReuseURLProtocol.requestCount == 0)
		#expect(result.downloadedFiles == 1)
		#expect(try Data(contentsOf: world.destination) == Self.body)
		#expect(try FileSnapshot(donor.file) == before)
		#expect(!FileManager.default.fileExists(atPath: world.destination.path + ".part"))
		#expect(try world.stagingEntries().isEmpty)
		let updates = await recorder.updates()
		#expect(updates.last?.downloadedBytes == Int64(Self.body.count))
		#expect(updates.last?.completedFiles == 1)
		#expect(updates.allSatisfy { $0.networkDownloadedBytes == 0 })
		#expect(updates.allSatisfy { $0.transferRateBytesPerSecond == nil })
	}

	@Test
	func donorWithSameSizeButDifferentContentFallsBackToDownload() async throws {
		let world = try ReuseWorld()
		defer { world.remove() }
		let wrong = Data(repeating: 0x7F, count: Self.body.count)
		let donor = try world.makeDonor(body: wrong)
		let before = try FileSnapshot(donor.file)

		_ = try await world.install(donors: [donor.directory])

		#expect(ReuseURLProtocol.requestCount == 1)
		#expect(try Data(contentsOf: world.destination) == Self.body)
		#expect(try FileSnapshot(donor.file) == before)
		#expect(try world.stagingEntries().isEmpty)
	}

	@Test
	func donorWithDifferentSizeFallsBackToDownload() async throws {
		let world = try ReuseWorld()
		defer { world.remove() }
		let donor = try world.makeDonor(body: Self.body.prefix(100))

		_ = try await world.install(donors: [donor.directory])

		#expect(ReuseURLProtocol.requestCount == 1)
		#expect(try Data(contentsOf: world.destination) == Self.body)
	}

	@Test
	func unreadableDonorFileFallsBackToDownload() async throws {
		let world = try ReuseWorld()
		defer { world.remove() }
		let donor = try world.makeDonor(body: Self.body)
		#expect(chmod(donor.file.path, 0) == 0)

		_ = try await world.install(donors: [donor.directory])

		#expect(ReuseURLProtocol.requestCount == 1)
		#expect(try Data(contentsOf: world.destination) == Self.body)
		#expect(chmod(donor.file.path, 0o644) == 0)
	}

	@Test
	func laterDonorIsUsedWhenAnEarlierOneDoesNotMatch() async throws {
		let world = try ReuseWorld()
		defer { world.remove() }
		let wrong = try world.makeDonor(
			name: "wrong", body: Data(repeating: 1, count: Self.body.count))
		let right = try world.makeDonor(name: "right", body: Self.body)

		_ = try await world.install(donors: [wrong.directory, right.directory])

		#expect(ReuseURLProtocol.requestCount == 0)
		#expect(try Data(contentsOf: world.destination) == Self.body)
	}

	@Test
	func regionNeverReusesItsOwnDirectory() async throws {
		let world = try ReuseWorld()
		defer { world.remove() }
		_ = try world.writeInstalledRegion(at: world.target, body: Self.body)
		let alias = world.root.appending(path: "alias", directoryHint: .isDirectory)
		try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: world.target)
		let root = try InstallerInstallDirectory(at: world.target)

		let session = await world.installer(donors: [world.target, alias])
			.reuseSession(for: .global, target: root)

		#expect(session.sources.isEmpty)
	}

	@Test
	func incompleteRegionsAreNotSources() async throws {
		let world = try ReuseWorld()
		defer { world.remove() }
		let noState = try world.makeDonor(name: "no-state", body: Self.body)
		try FileManager.default.removeItem(at: noState.directory.appending(path: stateName))
		let noExecutable = try world.makeDonor(name: "no-exe", body: Self.body)
		try FileManager.default.removeItem(
			at: noExecutable.directory.appending(path: "Arknights.exe"))
		let corruptState = try world.makeDonor(name: "corrupt", body: Self.body)
		try Data("{".utf8).write(to: corruptState.directory.appending(path: stateName))
		let missing = world.root.appending(path: "missing", directoryHint: .isDirectory)

		_ = try await world.install(
			donors: [noState.directory, noExecutable.directory, corruptState.directory, missing]
		)

		#expect(ReuseURLProtocol.requestCount == 1)
		#expect(try Data(contentsOf: world.destination) == Self.body)
	}

	@Test
	func donorThatDoesNotListThePathIsSkipped() async throws {
		let world = try ReuseWorld()
		defer { world.remove() }
		let donor = try world.makeDonor(body: Self.body, listedPath: "other/file.dat")

		_ = try await world.install(donors: [donor.directory])

		#expect(ReuseURLProtocol.requestCount == 1)
	}

	private var stateName: String { AppConstants.Game.installedStateFileName }
}

private struct FileSnapshot: Equatable {
	let inode: ino_t
	let size: off_t
	let modified: timespec
	let contents: Data

	init(_ url: URL) throws {
		var status = stat()
		guard stat(url.path, &status) == 0 else { throw POSIXError(.ENOENT) }
		inode = status.st_ino
		size = status.st_size
		modified = status.st_mtimespec
		contents = try Data(contentsOf: url)
	}

	static func == (lhs: Self, rhs: Self) -> Bool {
		lhs.inode == rhs.inode && lhs.size == rhs.size
			&& lhs.modified.tv_sec == rhs.modified.tv_sec
			&& lhs.modified.tv_nsec == rhs.modified.tv_nsec && lhs.contents == rhs.contents
	}
}

final class ReuseURLProtocol: URLProtocol, @unchecked Sendable {
	nonisolated(unsafe) static var requestCount = 0
	nonisolated(unsafe) static var body = Data()

	override class func canInit(with request: URLRequest) -> Bool { true }
	override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

	override func startLoading() {
		Self.requestCount += 1
		let response = GameInstallerStreamingTests.response(url: request.url!, status: 200)
		client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
		client?.urlProtocol(self, didLoad: Self.body)
		client?.urlProtocolDidFinishLoading(self)
	}

	override func stopLoading() {}
}

private struct ReuseWorld {
	let fixture: InstallerFixture
	let root: URL
	var target: URL { fixture.directory }
	var destination: URL { fixture.destination }

	init() throws {
		let body = Data((0..<4_096).map { UInt8($0 % 251) })
		fixture = try GameInstallerStreamingTests.makeFixture(
			body: body, protocolClass: ReuseURLProtocol.self)
		root = FileManager.default.temporaryDirectory.appending(
			path: "GameInstallerReuseTests-\(UUID().uuidString)", directoryHint: .isDirectory)
		try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
		ReuseURLProtocol.requestCount = 0
		ReuseURLProtocol.body = body
	}

	func remove() {
		fixture.remove()
		try? FileManager.default.removeItem(at: root)
	}

	func installer(donors: [URL]) -> GameInstaller {
		let configuration = URLSessionConfiguration.ephemeral
		configuration.protocolClasses = [ReuseURLProtocol.self]
		return GameInstaller(
			api: InstallerAPI(
				manifest: GameManifest(source: fixture.source, file: [fixture.item]),
				cdn: CDNConfiguration(primaryCdn: fixture.baseURL, backUpCdn: fixture.baseURL)
			),
			session: URLSession(configuration: configuration),
			compatibilityManager: GameCompatibilityManager(),
			reuseSourceDirectories: { _ in donors }
		)
	}

	func install(
		donors: [URL],
		progress: @escaping @Sendable (DownloadProgress) async -> Void = { _ in }
	) async throws -> InstallResult {
		try await installer(donors: donors).install(
			configuration: fixture.configuration,
			region: .global,
			into: target,
			progress: progress
		)
	}

	/// A complete region directory that holds `body` at the manifest path.
	func makeDonor(
		name: String = "donor",
		body: some DataProtocol,
		listedPath: String? = nil
	) throws -> (directory: URL, file: URL) {
		let directory = root.appending(path: name, directoryHint: .isDirectory)
		return (
			directory,
			try writeInstalledRegion(
				at: directory, body: Data(body), listedPath: listedPath ?? fixture.item.path)
		)
	}

	@discardableResult
	func writeInstalledRegion(at directory: URL, body: Data, listedPath: String? = nil) throws
		-> URL
	{
		let file = directory.appending(path: fixture.item.path)
		try FileManager.default.createDirectory(
			at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
		try body.write(to: file)
		try Data().write(to: directory.appending(path: "Arknights.exe"))
		let state = InstalledState(
			version: "1.0.0",
			basis: "manifest.json",
			source: fixture.source,
			installedAt: Date(),
			files: [
				ManifestFile(
					path: listedPath ?? fixture.item.path, hash: fixture.item.hash,
					size: fixture.item.size)
			]
		)
		let encoder = JSONEncoder()
		encoder.dateEncodingStrategy = .iso8601
		try encoder.encode(state).write(
			to: directory.appending(path: AppConstants.Game.installedStateFileName))
		return file
	}

	func stagingEntries() throws -> [String] {
		let staging = target.appending(path: AppConstants.Game.installerStagingDirectoryName)
		return try FileManager.default.contentsOfDirectory(atPath: staging.path)
			.filter { $0.hasPrefix("reuse-") || $0.hasPrefix("payload-") }
	}
}
