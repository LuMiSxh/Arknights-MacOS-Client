// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

private func manifestFile(hash: String = "1", size: String = "10") -> ManifestFile {
	ManifestFile(path: "bin/Arknights.exe", hash: hash, size: size)
}

@Test
func needsDownloadUsesSizeAndPreviousManifestBeforeHashing() {
	let cases: [(String, String?, Int64?, Bool, Bool, Int)] = [
		("1", "1", nil, false, true, 0),
		("1", "1", 9, false, true, 0),
		("2", "1", 10, false, true, 0),
		("1", "1", 10, false, false, 0),
		("1", "1", 10, true, true, 1),
		("1", nil, 10, false, false, 1),
	]
	for (hash, previousHash, destinationSize, verify, expected, checksumCallsExpected) in cases {
		let item = manifestFile(hash: hash)
		var checksumCalls = 0
		let result = GameInstaller.needsDownload(
			item,
			destinationSize: destinationSize,
			previousFile: previousHash.map { manifestFile(hash: $0) },
			verifyAllExistingFiles: verify,
			checksum: {
				checksumCalls += 1
				return verify ? "corrupted" : item.hash
			}
		)
		#expect(result == expected)
		#expect(checksumCalls == checksumCallsExpected)
	}
}

@Test
func diskCapacityFailureIsTypedWhenNoDirectoryCanBeRead() {
	#expect(throws: DiskCapacityError.self) {
		_ = try GameInstaller.availableCapacityBytes(
			at: URL(filePath: "/dev/null/arknights-client-install"))
	}
}

@Test(arguments: ["-1", "+1", "01", " 1", "1.0", "9223372036854775808"])
func manifestDecodeRejectsInvalidSizes(_ size: String) {
	#expect(throws: DecodingError.self) {
		_ = try JSONDecoder().decode(ManifestFile.self, from: manifestJSON(hash: "0", size: size))
	}
}

@Test
func manifestValidationRejectsPerFileAndAggregateLimits() throws {
	let installer = GameInstaller(
		api: InstallerAPI(
			manifest: GameManifest(source: "payload", file: []),
			cdn: CDNConfiguration(
				primaryCdn: URL(string: "https://example.invalid")!,
				backUpCdn: URL(string: "https://example.invalid")!)),
		compatibilityManager: GameCompatibilityManager())
	let root = URL(filePath: "/tmp/manifest-validation")
	let file = try decodeManifestFile(path: "large", size: "1099511627777")
	#expect(throws: LauncherError.self) {
		try installer.validateManifest(GameManifest(source: "payload", file: [file]), inside: root)
	}
	let maximum = try decodeManifestFile(path: "file", size: "1099511627776")
	let aggregate = GameManifest(
		source: "payload",
		file: (0..<5).map {
			ManifestFile(path: "\(maximum.path)-\($0)", hash: maximum.hash, size: maximum.size)
		})
	#expect(throws: LauncherError.self) { try installer.validateManifest(aggregate, inside: root) }
}

private func decodeManifestFile(path: String, size: String) throws -> ManifestFile {
	try JSONDecoder().decode(
		ManifestFile.self, from: manifestJSON(path: path, hash: "0", size: size))
}

private func manifestJSON(path: String = "bin/game.dat", hash: String, size: String) -> Data {
	Data(#"{"path":"\#(path)","hash":"\#(hash)","size":"\#(size)"}"#.utf8)
}
