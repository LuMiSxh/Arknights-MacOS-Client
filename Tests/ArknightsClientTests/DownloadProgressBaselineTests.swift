// SPDX-License-Identifier: MPL-2.0

import Testing

@testable import ArknightsClient

struct DownloadProgressBaselineTests {
	@Test
	func incompleteInstallationCountsFinishedAndPartialFiles() {
		let complete = manifestFile(path: "complete", size: 300)
		let partial = manifestFile(path: "partial", size: 700)

		let baseline = DownloadProgressBaseline(
			manifestFiles: [complete, partial],
			pendingFiles: [partial],
			isIncompleteInstallation: true,
			partialSize: { _ in 200 }
		)

		#expect(baseline.totalBytes == 1_000)
		#expect(baseline.downloadedBytes == 500)
		#expect(baseline.totalFiles == 2)
		#expect(baseline.completedFiles == 1)
	}

	@Test
	func updateMeasuresOnlyChangedFiles() {
		let unchanged = manifestFile(path: "unchanged", size: 300)
		let changed = manifestFile(path: "changed", size: 700)

		let baseline = DownloadProgressBaseline(
			manifestFiles: [unchanged, changed],
			pendingFiles: [changed],
			isIncompleteInstallation: false,
			partialSize: { _ in 200 }
		)

		#expect(baseline.totalBytes == 700)
		#expect(baseline.downloadedBytes == 200)
		#expect(baseline.totalFiles == 1)
		#expect(baseline.completedFiles == 0)
	}

	private func manifestFile(path: String, size: Int64) -> ManifestFile {
		ManifestFile(path: path, hash: "0", size: String(size))
	}
}
