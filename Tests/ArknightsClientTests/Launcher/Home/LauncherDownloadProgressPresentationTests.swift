// SPDX-License-Identifier: MPL-2.0

import Testing

@testable import ArknightsClient

@Test
func launcherDownloadProgressDoesNotInventPercentageWithoutKnownTotal() {
	let preparing = DownloadProgress(
		downloadedBytes: 0,
		totalBytes: 0,
		completedFiles: 0,
		totalFiles: 0,
		currentFile: ""
	)
	let active = DownloadProgress(
		downloadedBytes: 68,
		totalBytes: 100,
		completedFiles: 1,
		totalFiles: 2,
		currentFile: "client.zip"
	)
	let pausedUnknown = DownloadProgress(
		downloadedBytes: 0,
		totalBytes: 0,
		completedFiles: 0,
		totalFiles: 0,
		currentFile: "client.zip",
		isTransferStalled: true
	)
	let pausedKnown = DownloadProgress(
		downloadedBytes: 68,
		totalBytes: 100,
		completedFiles: 1,
		totalFiles: 2,
		currentFile: "client.zip",
		transferRateBytesPerSecond: 4_200_000,
		isTransferStalled: true
	)
	let complete = DownloadProgress(
		downloadedBytes: 100,
		totalBytes: 100,
		completedFiles: 2,
		totalFiles: 2,
		currentFile: "client.zip"
	)

	#expect(LauncherDownloadProgressPresentation.percentage(for: nil) == nil)
	#expect(LauncherDownloadProgressPresentation.percentage(for: preparing) == nil)
	#expect(LauncherDownloadProgressPresentation.percentage(for: active) == 68)
	#expect(
		LauncherDownloadProgressPresentation.fraction(
			for: active,
			isActive: false,
			isPaused: false
		) == nil
	)
	#expect(
		LauncherDownloadProgressPresentation.fraction(
			for: active,
			isActive: true,
			isPaused: false
		) == 0.68
	)
	#expect(
		LauncherDownloadProgressPresentation.outlineFraction(
			for: active,
			status: .downloading,
			hasPartialDownload: false,
			hasFailure: false
		) == 0.68
	)
	#expect(
		LauncherDownloadProgressPresentation.outlineFraction(
			for: pausedKnown,
			status: .paused,
			hasPartialDownload: true,
			hasFailure: false
		) == 0.68
	)
	#expect(
		LauncherDownloadProgressPresentation.outlineFraction(
			for: pausedKnown,
			status: .downloading,
			hasPartialDownload: false,
			hasFailure: false
		) == 0.68
	)
	#expect(
		LauncherDownloadProgressPresentation.outlineFraction(
			for: active,
			status: .preparingInstallation,
			hasPartialDownload: false,
			hasFailure: false
		) == 1
	)
	#expect(
		LauncherDownloadProgressPresentation.outlineFraction(
			for: active,
			status: .verifyingInstallation,
			hasPartialDownload: false,
			hasFailure: false
		) == 1
	)
	#expect(
		LauncherDownloadProgressPresentation.outlineFraction(
			for: complete,
			status: .downloading,
			hasPartialDownload: false,
			hasFailure: false
		) == 1
	)
	#expect(
		LauncherDownloadProgressPresentation.outlineFraction(
			for: active,
			status: .ready,
			hasPartialDownload: true,
			hasFailure: false
		) == nil
	)
	#expect(
		LauncherDownloadProgressPresentation.showsActiveProgressEffect(
			for: active,
			status: .downloading,
			hasFailure: false
		)
	)
	#expect(
		!LauncherDownloadProgressPresentation.showsActiveProgressEffect(
			for: active,
			status: .paused,
			hasFailure: false
		)
	)
	#expect(
		!LauncherDownloadProgressPresentation.showsActiveProgressEffect(
			for: pausedKnown,
			status: .downloading,
			hasFailure: false
		)
	)
	#expect(
		LauncherDownloadProgressPresentation.showsActiveProgressEffect(
			for: preparing,
			status: .preparingInstallation,
			hasFailure: false
		)
	)
	#expect(
		LauncherDownloadProgressPresentation.showsActiveProgressEffect(
			for: active,
			status: .verifyingInstallation,
			hasFailure: false
		)
	)
	#expect(
		!LauncherDownloadProgressPresentation.showsActiveProgressEffect(
			for: active,
			status: .downloading,
			hasFailure: true
		)
	)
	#expect(
		!LauncherDownloadProgressPresentation.showsActiveProgressEffect(
			for: complete,
			status: .downloading,
			hasFailure: false
		)
	)
	#expect(
		LauncherDownloadProgressPresentation.fraction(
			for: active,
			isActive: false,
			isPaused: true
		) == 0.68
	)
	#expect(
		LauncherDownloadProgressPresentation.fraction(
			for: pausedUnknown,
			isActive: false,
			isPaused: true
		) == nil
	)
	#expect(
		LauncherDownloadProgressPresentation.title(for: pausedKnown, isPaused: true)
			== "Paused · 68%"
	)
	#expect(
		LauncherDownloadProgressPresentation.transferDetail(
			for: pausedKnown,
			isPaused: true
		) == nil
	)
	#expect(
		LauncherDownloadProgressPresentation.transferDetail(
			for: pausedKnown,
			isPaused: false
		) != nil
	)
	#expect(
		LauncherDownloadProgressPresentation.transferDetail(
			for: pausedUnknown,
			isPaused: false
		) == HomeStrings.downloadWaiting
	)
	#expect(
		LauncherDownloadProgressPresentation.accessibilityValue(
			for: pausedKnown,
			detail: "1.73 GB of 4.03 GB",
			isPaused: true
		) == "1.73 GB of 4.03 GB"
	)
}
