// SPDX-License-Identifier: MPL-2.0

import Testing

@testable import ArknightsClient

private func manifestFile(hash: String = "expected", size: String = "10") -> ManifestFile {
	ManifestFile(path: "bin/Arknights.exe", hash: hash, size: size)
}

@Test
func missingOrWrongSizedDestinationNeedsDownloadWithoutChecksum() {
	let item = manifestFile()
	var checksumCalls = 0

	let missing = GameInstaller.needsDownload(
		item,
		destinationSize: nil,
		previousFile: item,
		verifyAllExistingFiles: false,
		checksum: {
			checksumCalls += 1
			return item.hash
		}
	)
	let wrongSize = GameInstaller.needsDownload(
		item,
		destinationSize: 9,
		previousFile: item,
		verifyAllExistingFiles: false,
		checksum: {
			checksumCalls += 1
			return item.hash
		}
	)

	#expect(missing)
	#expect(wrongSize)
	#expect(checksumCalls == 0)
}

@Test
func changedManifestHashNeedsDownloadWhenSizeMatches() {
	let item = manifestFile(hash: "new")
	let previousFile = manifestFile(hash: "old")
	var checksumCalls = 0

	let needsDownload = GameInstaller.needsDownload(
		item,
		destinationSize: item.byteCount,
		previousFile: previousFile,
		verifyAllExistingFiles: false,
		checksum: {
			checksumCalls += 1
			return item.hash
		}
	)

	#expect(needsDownload)
	#expect(checksumCalls == 0)
}

@Test
func matchingManifestHashReusesFileDuringUpdate() {
	let item = manifestFile()
	var checksumCalls = 0

	let needsDownload = GameInstaller.needsDownload(
		item,
		destinationSize: item.byteCount,
		previousFile: item,
		verifyAllExistingFiles: false,
		checksum: {
			checksumCalls += 1
			return "unexpected"
		}
	)

	#expect(!needsDownload)
	#expect(checksumCalls == 0)
}

@Test
func repairVerifiesChecksumAndRedownloadsMismatch() {
	let item = manifestFile()
	var checksumCalls = 0

	let needsDownload = GameInstaller.needsDownload(
		item,
		destinationSize: item.byteCount,
		previousFile: item,
		verifyAllExistingFiles: true,
		checksum: {
			checksumCalls += 1
			return "corrupted"
		}
	)

	#expect(needsDownload)
	#expect(checksumCalls == 1)
}

@Test
func stateWithoutFileMetadataVerifiesChecksum() {
	let item = manifestFile()
	var checksumCalls = 0

	let needsDownload = GameInstaller.needsDownload(
		item,
		destinationSize: item.byteCount,
		previousFile: nil,
		verifyAllExistingFiles: false,
		checksum: {
			checksumCalls += 1
			return item.hash
		}
	)

	#expect(!needsDownload)
	#expect(checksumCalls == 1)
}
