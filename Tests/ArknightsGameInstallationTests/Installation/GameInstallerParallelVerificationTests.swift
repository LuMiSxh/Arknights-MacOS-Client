// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsTestSupport
import Darwin
import Foundation
import Synchronization
import Testing

@testable import ArknightsGameInstallation
@testable import ArknightsInfrastructure

struct GameInstallerParallelVerificationTests {
	private struct Fixture {
		let temporary: TemporaryDirectory
		let manifest: GameManifest
		let installer: GameInstaller

		var directory: URL { temporary.url }

		func remove() {
			temporary.remove()
		}

		func pending(
			progress: @escaping GameInstaller.ProgressHandler = { _ in },
			willHash: @escaping @Sendable (String) -> Void = { _ in },
			didRead: @escaping @Sendable (Int) -> Void = { _ in }
		) async throws -> GameInstaller.PendingDownloads {
			try await installer.pendingDownloads(
				in: manifest,
				installDirectory: InstallerDirectory(at: directory),
				previousFiles: nil,
				verifyAllExistingFiles: true,
				progress: progress,
				willHash: willHash,
				didRead: didRead
			)
		}
	}

	private static func makeFixture(bodies: [Data]) throws -> Fixture {
		let temporary = try TemporaryDirectory("GameInstallerParallelVerificationTests")
		var files: [ManifestFile] = []
		for (index, body) in bodies.enumerated() {
			var checksum = CRC64()
			checksum.update(body)
			let path = "file-\(index).dat"
			files.append(
				ManifestFile(path: path, hash: checksum.decimalString, size: String(body.count)))
			try body.write(to: temporary.url.appending(path: path))
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
			temporary: temporary,
			manifest: GameManifest(source: "payload", file: files),
			installer: installer
		)
	}

	private static func bodies(count: Int, size: Int) -> [Data] {
		(0..<count).map { Data(repeating: UInt8($0 + 1), count: size) }
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
