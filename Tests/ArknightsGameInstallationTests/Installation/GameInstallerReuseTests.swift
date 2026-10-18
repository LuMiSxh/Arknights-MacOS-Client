// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsTestSupport
import Darwin
import Foundation
import Testing

@testable import ArknightsGameInstallation

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

		#expect(world.fixture.route.requestCount == 0)
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
		// Each row builds its own world and lists the donors that must not be reused.
		let rows: [(String, @Sendable (ReuseWorld) throws -> [URL])] = [
			(
				"same size, different content",
				{ world in
					let donor = try world.makeDonor(
						body: Data(repeating: 0x7F, count: Self.body.count))
					return [donor.directory]
				}
			),
			(
				"different size",
				{ world in [try world.makeDonor(body: Self.body.prefix(100)).directory] }
			),
			(
				"unreadable file",
				{ world in
					let donor = try world.makeDonor(body: Self.body)
					#expect(chmod(donor.file.path, 0) == 0)
					return [donor.directory]
				}
			),
			(
				"incomplete regions",
				{ world in
					let noState = try world.makeDonor(name: "no-state", body: Self.body)
					try FileManager.default.removeItem(
						at: noState.directory.appending(path: Self.stateName))
					let noExecutable = try world.makeDonor(name: "no-exe", body: Self.body)
					try FileManager.default.removeItem(
						at: noExecutable.directory.appending(path: "Arknights.exe"))
					let corrupt = try world.makeDonor(name: "corrupt", body: Self.body)
					try Data("{".utf8).write(to: corrupt.directory.appending(path: Self.stateName))
					let missing = world.root.appending(path: "missing", directoryHint: .isDirectory)
					return [noState.directory, noExecutable.directory, corrupt.directory, missing]
				}
			),
			(
				"path not listed",
				{ world in
					[try world.makeDonor(body: Self.body, listedPath: "other/file.dat").directory]
				}
			),
		]
		for (scenario, makeDonors) in rows {
			let world = try ReuseWorld()
			defer { world.remove() }
			let donors = try makeDonors(world)
			let files = donors.map { $0.appending(path: world.fixture.item.path) }
			let snapshots = files.map { FileSnapshot.ifReadable($0) }

			_ = try await world.install(donors: donors)

			#expect(world.fixture.route.requestCount == 1, "\(scenario)")
			#expect(try Data(contentsOf: world.destination) == Self.body, "\(scenario)")
			#expect(try world.stagingEntries().isEmpty, "\(scenario)")
			for file in files { _ = chmod(file.path, 0o644) }
			let after = zip(files, snapshots).map { $1 == nil ? nil : FileSnapshot.ifReadable($0) }
			#expect(snapshots == after, "\(scenario)")
		}

		// A later matching donor is used when an earlier one does not match.
		let world = try ReuseWorld()
		defer { world.remove() }
		let wrong = try world.makeDonor(
			name: "wrong", body: Data(repeating: 1, count: Self.body.count))
		let right = try world.makeDonor(name: "right", body: Self.body)
		_ = try await world.install(donors: [wrong.directory, right.directory])
		#expect(world.fixture.route.requestCount == 0)
		#expect(try Data(contentsOf: world.destination) == Self.body)

		// A region never reuses its own directory, even through an alias.
		let own = try ReuseWorld()
		defer { own.remove() }
		_ = try own.writeInstalledRegion(at: own.target, body: Self.body)
		let alias = own.root.appending(path: "alias", directoryHint: .isDirectory)
		try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: own.target)
		try await withTestInstallDirectory(at: own.target) { root in
			let session = await own.installer(donors: [own.target, alias])
				.reuseSession(for: .global, target: root)
			#expect(session.sources.isEmpty)
		}
	}

	private static var stateName: String { AppConstants.Game.installedStateFileName }
}

private struct FileSnapshot: Equatable {
	let inode: ino_t
	let size: off_t
	let modified: timespec
	let contents: Data

	static func ifReadable(_ url: URL) -> FileSnapshot? {
		do {
			return try FileSnapshot(url)
		} catch {
			return nil
		}
	}

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

/// A game install target plus donor regions, all under one temporary root.
private struct ReuseWorld {
	let fixture: InstallerFixture
	var root: URL { fixture.temporary.url }
	var target: URL { fixture.directory }
	var destination: URL { fixture.destination }

	init() throws {
		let body = Data((0..<4_096).map { UInt8($0 % 251) })
		fixture = try InstallerFixture.make(body: body)
		fixture.route.handler = { request in
			(makeHTTPResponse(url: request.url!, status: 200), body)
		}
	}

	func remove() {
		fixture.remove()
	}

	func installer(donors: [URL]) -> GameInstaller {
		GameInstaller(
			api: InstallerAPI(
				manifest: GameManifest(source: fixture.source, file: [fixture.item]),
				cdn: CDNConfiguration(primaryCdn: fixture.baseURL, backUpCdn: fixture.baseURL)
			),
			session: fixture.route.session,
			compatibilityManager: GameCompatibilityManager(),
			reuseSourceDirectories: { _ in donors }
		)
	}

	func install(
		donors: [URL],
		progress: @escaping @Sendable (DownloadProgress) async -> Void = { _ in }
	) async throws -> InstallResult {
		try await installer(donors: donors).install(
			configuration: installerTestConfiguration,
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
	func writeInstalledRegion(
		at directory: URL, body: Data, listedPath: String? = nil
	) throws
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
