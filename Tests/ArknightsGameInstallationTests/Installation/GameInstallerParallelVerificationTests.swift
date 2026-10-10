// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Darwin
import Foundation
import Synchronization
import Testing

@testable import ArknightsGameInstallation
@testable import ArknightsInfrastructure

struct GameInstallerParallelVerificationTests {
	private struct Fixture {
		let directory: URL
		let manifest: GameManifest
		let installer: GameInstaller

		func remove() {
			do {
				try FileManager.default.removeItem(at: directory)
			} catch {
				Issue.record("Could not remove \(directory.path): \(error)")
			}
		}

		func pending(
			progress: @escaping GameInstaller.ProgressHandler = { _ in },
			willHash: @escaping @Sendable (String) -> Void = { _ in },
			didRead: @escaping @Sendable (Int) -> Void = { _ in }
		) async throws -> GameInstaller.PendingDownloads {
			try await installer.pendingDownloads(
				in: manifest,
				installDirectory: try InstallerInstallDirectory(pinningAt: directory),
				previousFiles: nil,
				verifyAllExistingFiles: true,
				progress: progress,
				willHash: willHash,
				didRead: didRead
			)
		}
	}

	/// Writes `bodies`; entries whose index is in `corrupt` get different bytes of the same size.
	private static func makeFixture(
		bodies: [Data],
		corrupt: Set<Int> = []
	) throws -> Fixture {
		let directory = FileManager.default.temporaryDirectory.appending(
			path: "GameInstallerParallelVerificationTests-\(UUID().uuidString)",
			directoryHint: .isDirectory
		)
		try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
		var files: [ManifestFile] = []
		for (index, body) in bodies.enumerated() {
			var checksum = CRC64()
			checksum.update(body)
			let path = "file-\(index).dat"
			files.append(
				ManifestFile(path: path, hash: checksum.decimalString, size: String(body.count)))
			let stored = corrupt.contains(index) ? Data(repeating: 0xFF, count: body.count) : body
			try stored.write(to: directory.appending(path: path))
		}
		let installer = GameInstaller(
			api: InstallerAPI(
				manifest: GameManifest(source: "payload", file: files),
				cdn: CDNConfiguration(
					primaryCdn: URL(string: "https://download.yo-star.com")!,
					backUpCdn: URL(string: "https://download.yo-star.com")!)
			),
			compatibilityManager: GameCompatibilityManager()
		)
		return Fixture(
			directory: directory,
			manifest: GameManifest(source: "payload", file: files),
			installer: installer
		)
	}

	private static func bodies(count: Int, size: Int) -> [Data] {
		(0..<count).map { Data(repeating: UInt8($0 + 1), count: size) }
	}

	@Test
	func pendingFilesKeepManifestOrder() async throws {
		let corrupt: Set<Int> = [0, 3, 4, 9, 10]
		let fixture = try Self.makeFixture(
			bodies: Self.bodies(count: 12, size: 64 * 1_024), corrupt: corrupt)
		defer { fixture.remove() }

		let result = try await fixture.pending()

		#expect(result.files == corrupt.sorted().map { fixture.manifest.file[$0] })
	}

	@Test
	func progressByteTotalCoversEveryHashedFile() async throws {
		let size = 96 * 1_024
		let fixture = try Self.makeFixture(bodies: Self.bodies(count: 6, size: size))
		defer { fixture.remove() }
		let recorder = ProgressRecorderBox()

		let result = try await fixture.pending(progress: { recorder.record($0) })

		let updates = recorder.updates()
		let last = try #require(updates.last)
		#expect(result.files.isEmpty)
		#expect(updates.allSatisfy { $0.isVerifying && $0.totalBytes == Int64(6 * size) })
		#expect(last.downloadedBytes == Int64(6 * size))
		#expect(last.completedFiles == 6)
		#expect(last.totalFiles == 6)
		#expect(result.lastSequence == last.sequence)
	}

	@Test
	func identityChangeWhileHashingIsRejected() async throws {
		let fixture = try Self.makeFixture(bodies: Self.bodies(count: 1, size: 64 * 1_024))
		defer { fixture.remove() }
		let target = fixture.directory.appending(path: "file-0.dat")
		let swapped = Mutex(false)

		await #expect {
			try await fixture.pending(willHash: { _ in
				guard
					!swapped.withLock({
						let was = $0
						$0 = true
						return was
					})
				else { return }
				let replacement = target.appendingPathExtension("swap")
				do {
					try Data(repeating: 0x01, count: 64 * 1_024).write(to: replacement)
					try FileManager.default.removeItem(at: target)
					try FileManager.default.moveItem(at: replacement, to: target)
				} catch {
					Issue.record("Could not swap the file: \(error)")
				}
			})
		} throws: { error in
			guard case InstallerError.unsafeInstallerTemporaryFile = error else { return false }
			return true
		}
	}

	@Test
	func cancellationStopsEveryChild() async throws {
		let bufferCount = 3
		let fileCount = 12
		let fixture = try Self.makeFixture(
			bodies: Self.bodies(
				count: fileCount, size: bufferCount * AppConstants.IO.checksumBufferSize))
		defer { fixture.remove() }
		let reads = Atomic<Int>(0)
		let taskBox = Mutex<Task<GameInstaller.PendingDownloads, any Error>?>(nil)

		let task = Task {
			try await fixture.pending(didRead: { _ in
				reads.add(1, ordering: .relaxed)
				while taskBox.withLock({ $0 }) == nil { usleep(100) }
				taskBox.withLock { $0 }?.cancel()
			})
		}
		taskBox.withLock { $0 = task }

		await #expect(throws: CancellationError.self) { try await task.value }
		let observed = reads.load(ordering: .relaxed)
		#expect(observed <= 2 * AppConstants.IO.verificationConcurrency)
		#expect(observed < fileCount * bufferCount)
	}
}

private final class ProgressRecorderBox: Sendable {
	private let storage = Mutex<[DownloadProgress]>([])

	func record(_ update: DownloadProgress) {
		storage.withLock { $0.append(update) }
	}

	func updates() -> [DownloadProgress] {
		storage.withLock { $0 }
	}
}
