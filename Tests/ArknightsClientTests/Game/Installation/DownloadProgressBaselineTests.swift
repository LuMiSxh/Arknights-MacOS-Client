// SPDX-License-Identifier: MPL-2.0

import Testing

@testable import ArknightsClient

struct DownloadProgressBaselineTests {
	@Test(arguments: [
		("incomplete installation", true, 1_000, 500, 2, 1),
		("update", false, 700, 200, 1, 0),
	])
	func measuresThePendingFileBaseline(
		scenario: String,
		isIncompleteInstallation: Bool,
		expectedTotalBytes: Int64,
		expectedDownloadedBytes: Int64,
		expectedTotalFiles: Int,
		expectedCompletedFiles: Int
	) throws {
		let complete = manifestFile(path: "complete", size: 300)
		let pending = manifestFile(path: "pending", size: 700)
		let baseline = try DownloadProgressBaseline(
			manifestFiles: [complete, pending],
			pendingFiles: [pending],
			isIncompleteInstallation: isIncompleteInstallation,
			partialSize: { _ in 200 }
		)

		#expect(baseline.totalBytes == expectedTotalBytes, Comment(rawValue: scenario))
		#expect(baseline.downloadedBytes == expectedDownloadedBytes, Comment(rawValue: scenario))
		#expect(baseline.totalFiles == expectedTotalFiles, Comment(rawValue: scenario))
		#expect(baseline.completedFiles == expectedCompletedFiles, Comment(rawValue: scenario))
	}

	private func manifestFile(path: String, size: Int64) -> ManifestFile {
		ManifestFile(path: path, hash: "0", size: String(size))
	}
}
