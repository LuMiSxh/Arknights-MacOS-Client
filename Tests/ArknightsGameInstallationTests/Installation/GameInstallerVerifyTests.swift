// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsGameInstallation

struct GameInstallerVerifyTests {
	@Test
	func verifyReportsDamagedAndMissingFilesAndChangesNothing() async throws {
		let temporary = try TemporaryDirectory("GameInstallerVerifyTests")
		defer { temporary.remove() }
		let directory = temporary.url
		// The corrupted file keeps the expected size, so only its checksum reveals the damage.
		let files: [(path: String, expected: Data, onDisk: Data?)] = [
			("intact.dat", Data("intact-file".utf8), Data("intact-file".utf8)),
			("corrupted.dat", Data("game-data-v1".utf8), Data("game-data-v2".utf8)),
			("bin/missing.dat", Data("missing-file".utf8), nil),
		]
		let manifest = GameManifest(
			source: "payload",
			file: files.map { file in
				var checksum = CRC64()
				checksum.update(file.expected)
				return ManifestFile(
					path: file.path,
					hash: checksum.decimalString,
					size: String(file.expected.count)
				)
			}
		)
		for file in files {
			if let onDisk = file.onDisk {
				try onDisk.write(to: directory.appending(path: file.path))
			}
		}
		let installer = GameInstaller(
			api: InstallerAPI(
				manifest: manifest,
				cdn: CDNConfiguration(
					primaryCdn: URL(string: "https://download.yo-star.com")!,
					backUpCdn: URL(string: "https://download.yo-star.com")!
				)
			),
			compatibilityManager: GameCompatibilityManager()
		)

		let before = try snapshot(of: directory)
		let verification = try await installer.verify(
			configuration: installerTestConfiguration,
			region: .global,
			in: directory
		) { _ in }

		#expect(verification.damagedPaths == ["corrupted.dat", "bin/missing.dat"])
		#expect(try snapshot(of: directory) == before)
	}

	/// Every path under `directory` mapped to its bytes, or to `nil` for a folder. A write, rename,
	/// deletion, or new `.part` file changes the snapshot.
	private func snapshot(of directory: URL) throws -> [String: Data?] {
		var entries: [String: Data?] = [:]
		for path in try FileManager.default.subpathsOfDirectory(atPath: directory.path) {
			let url = directory.appending(path: path)
			var isDirectory: ObjCBool = false
			guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
				continue
			}
			entries.updateValue(
				isDirectory.boolValue ? nil : try Data(contentsOf: url),
				forKey: path
			)
		}
		return entries
	}
}
