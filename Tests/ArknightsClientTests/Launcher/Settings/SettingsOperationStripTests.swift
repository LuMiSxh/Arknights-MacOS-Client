// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Testing

@testable import ArknightsClient
@testable import ArknightsGameInstallation

@Suite
struct SettingsOperationStripTests {
	private static let progress = DownloadProgress(
		downloadedBytes: 42, totalBytes: 100, completedFiles: 1, totalFiles: 2, currentFile: "a")
	private static let verifying = DownloadProgress(
		downloadedBytes: 10, totalBytes: 100, completedFiles: 0, totalFiles: 2, currentFile: "a",
		isVerifying: true)

	@Test(
		arguments: [
			(LauncherStatus.checking, "Checking"),
			(.preparingInstallation, "Preparing"),
			(.pausing, "Pausing · 42%"),
			(.downloading, "Downloading · 42%"),
			(.paused, "Paused · 42%"),
			(.verifyingInstallation, "Verifying"),
			(.preparingWine, "Preparing Wine setup"),
			(.startingGame, "Starting"),
			(.stoppingGame, "Stopping"),
			(.movingToTrash, "Moving to Trash"),
			(.migratingStorage, "Updating launcher data"),
			(.deletingWinePrefix, "Deleting Wine prefix"),
			(.ready, nil), (.updateAvailable, nil), (.install, nil), (.updated, nil),
			(.running, nil), (.uninstalled, nil), (.winePrefixDeleted, nil),
			(.winePrefixResetScheduled, nil), (.gameExecutableNotFound, nil),
		] as [(LauncherStatus, String?)])
	func textCoversEveryStatus(status: LauncherStatus, expected: String?) {
		#expect(
			SettingsOperationStripPresentation.text(status: status, progress: Self.progress)
				== expected)
	}

	@Test
	func verificationShowsPercentageOnlyForVerificationProgress() {
		#expect(
			SettingsOperationStripPresentation.text(
				status: .verifyingInstallation, progress: Self.verifying) == "Verifying · 10%")
	}

	@Test
	func downloadWithoutKnownSizeShowsNoPercentage() {
		#expect(
			SettingsOperationStripPresentation.text(status: .downloading, progress: nil)
				== "Downloading")
	}

	@Test
	func accessibilityValueNamesPercentage() {
		#expect(
			SettingsOperationStripPresentation.accessibilityValue(
				status: .downloading, progress: Self.progress) == "42 percent")
		#expect(
			SettingsOperationStripPresentation.accessibilityValue(status: .checking, progress: nil)
				.isEmpty)
	}
}
