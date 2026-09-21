// SPDX-License-Identifier: MPL-2.0

import AppKit
import SwiftUI

struct LauncherUpdateView: View {
	let driver: LauncherUpdateUserDriver
	let accentColor: Color
	let hudTintColor: Color
	let checkForUpdates: () -> Void
	@State private var contentHeight: CGFloat = 0

	var body: some View {
		ThemedModalView(
			title: LauncherStrings.updateTitle,
			hudTintColor: hudTintColor,
			width: modalWidth,
			height: modalHeight
		) {
			VStack(alignment: .leading, spacing: 16) {
				statusHeader
				content
			}
			.onGeometryChange(for: CGFloat.self) { proxy in
				proxy.size.height
			} action: { newHeight in
				contentHeight = newHeight
			}
		} actions: {
			actions
		}
		.onExitCommand(perform: driver.dismissFromUser)
		.background {
			// This modal is a plain `.overlay` on the main window, not a `.sheet`, so
			// `onExitCommand` alone doesn't reliably receive Escape — a hidden button with
			// `.cancelAction` registers Escape as a real keyboard shortcut regardless of
			// presentation style.
			Button("", action: driver.dismissFromUser)
				.keyboardShortcut(.cancelAction)
				.hidden()
		}
	}

	private var statusHeader: some View {
		VStack(alignment: .leading, spacing: 6) {
			if let version = driver.version {
				Text(LauncherStrings.updateVersion(version))
					.font(.headline)
			}
			Text(statusText)
				.foregroundStyle(statusColor)
		}
		.accessibilityElement(children: .combine)
	}

	@ViewBuilder
	private var content: some View {
		switch driver.phase {
		case .hidden:
			EmptyView()
		case .checking:
			ProgressView()
				.controlSize(.large)
				.frame(maxWidth: .infinity, alignment: .center)
				.accessibilityLabel(Text(LauncherStrings.updateChecking))
		case .available:
			availableContent
		case .downloading:
			downloadContent
		case .extracting:
			extractionContent
		case .readyToInstall:
			Text(LauncherStrings.updateReadyDetail)
				.foregroundStyle(.secondary)
		case .installing:
			installingContent
		case .installed:
			Text(

				driver.relaunched
					? LauncherStrings.updateRelaunchDetail
					: LauncherStrings.updateInstalledDetail

			)
			.foregroundStyle(.secondary)
		case .noUpdate:
			Text(LauncherStrings.updateNoUpdateDetail)
				.foregroundStyle(.secondary)
		case .failed:
			Text(driver.message ?? LauncherStrings.updateErrorDetail)
				.foregroundStyle(.secondary)
				.textSelection(.enabled)
		}
	}

	private var availableContent: some View {
		VStack(alignment: .leading, spacing: 14) {
			if let releaseNotes = driver.releaseNotes, !releaseNotes.isEmpty {
				if driver.releaseNotesFormat == "markdown" {
					MarkdownDocument(source: releaseNotes, accentColor: accentColor)
				} else {
					Text(releaseNotes)
						.textSelection(.enabled)
				}
			} else {
				Text(LauncherStrings.updateReleaseNotesUnavailable)
					.foregroundStyle(.secondary)
			}
			if driver.informationOnly {
				Text(LauncherStrings.updateInformationOnlyDetail)
					.foregroundStyle(.secondary)
			}
		}
	}

	private var downloadContent: some View {
		VStack(alignment: .leading, spacing: 10) {
			ProgressView(value: downloadProgress)
				.tint(accentColor)
				.accessibilityLabel(Text(LauncherStrings.updateDownloading))
				.accessibilityValue(Text(downloadProgressText))
			Text(downloadProgressText)
				.font(.caption.monospacedDigit())
				.foregroundStyle(.secondary)
		}
	}

	private var extractionContent: some View {
		VStack(alignment: .leading, spacing: 10) {
			ProgressView(value: driver.extractionProgress)
				.tint(accentColor)
				.accessibilityLabel(Text(LauncherStrings.updateExtracting))
				.accessibilityValue(Text(percentageText))
			Text(percentageText)
				.font(.caption.monospacedDigit())
				.foregroundStyle(.secondary)
		}
	}

	private var installingContent: some View {
		VStack(alignment: .leading, spacing: 10) {
			ProgressView()
				.accessibilityLabel(Text(LauncherStrings.updateInstalling))
			Text(
				driver.message
					?? (driver.gameIsRunning
						? LauncherStrings.updateQuitDetail
						: driver.terminationBlocked
							? LauncherStrings.updateWaitingDetail
							: LauncherStrings.updateInstallingDetail)
			)
			.foregroundStyle(.secondary)
		}
	}

	@ViewBuilder
	private var actions: some View {
		switch driver.phase {
		case .checking:
			CapsuleActionButton(
				title: LauncherStrings.updateCancel,
				tone: .neutral,
				action: driver.cancelCheck
			)
		case .available:
			CapsuleActionButton(
				title: LauncherStrings.updateLater,
				tone: .neutral,
				action: { driver.choose(.dismiss) }
			)
			if driver.informationOnly {
				if let informationURL = driver.informationURL {
					CapsuleActionButton(
						title: LauncherStrings.updateMoreInformation,
						systemImage: "arrow.up.right",
						tone: .neutral
					) { NSWorkspace.shared.open(informationURL) }
				}
			} else {
				CapsuleActionButton(
					title: LauncherStrings.updateInstall,
					systemImage: "arrow.down.app",
					tone: .accent(accentColor),
					action: { driver.choose(.install) }
				)
				.keyboardShortcut(.defaultAction)
			}
		case .downloading:
			CapsuleActionButton(
				title: LauncherStrings.updateCancel,
				tone: .neutral,
				action: driver.cancelDownload
			)
		case .extracting:
			EmptyView()
		case .readyToInstall:
			CapsuleActionButton(
				title: LauncherStrings.updateLater,
				tone: .neutral,
				action: { driver.choose(.dismiss) }
			)
			CapsuleActionButton(
				title: LauncherStrings.updateInstallNow,
				systemImage: "arrow.down.app",
				tone: .accent(accentColor),
				action: { driver.choose(.install) }
			)
			.keyboardShortcut(.defaultAction)
		case .installing:
			if !driver.applicationTerminated {
				CapsuleActionButton(
					title: LauncherStrings.updateRetryQuit,
					systemImage: "arrow.clockwise",
					tone: .accent(accentColor),
					action: driver.retryTerminationRequest
				)
			}
		case .installed:
			CapsuleActionButton(
				title: LauncherStrings.updateDone,
				tone: .neutral,
				action: driver.acknowledge
			)
		case .noUpdate:
			CapsuleActionButton(
				title: LauncherStrings.updateCheckAgain,
				systemImage: "arrow.clockwise",
				tone: .accent(accentColor),
				action: retryUpdate
			)
			CapsuleActionButton(
				title: LauncherStrings.updateDone,
				tone: .neutral,
				action: driver.acknowledge
			)
		case .failed:
			CapsuleActionButton(
				title: LauncherStrings.updateTryAgain,
				systemImage: "arrow.clockwise",
				tone: .accent(accentColor),
				action: retryUpdate
			)
			.keyboardShortcut(.defaultAction)
			CapsuleActionButton(
				title: LauncherStrings.updateDone,
				tone: .neutral,
				action: driver.acknowledge
			)
		case .hidden:
			EmptyView()
		}
	}

	private var statusText: String {
		switch driver.phase {
		case .hidden: ""
		case .checking: LauncherStrings.updateChecking
		case .available: availableStatusText
		case .downloading: LauncherStrings.updateDownloading
		case .extracting: LauncherStrings.updateExtracting
		case .readyToInstall: LauncherStrings.updateReady
		case .installing: LauncherStrings.updateInstalling
		case .installed: LauncherStrings.updateInstalled
		case .noUpdate: LauncherStrings.updateNoUpdate
		case .failed: LauncherStrings.updateFailed
		}
	}

	private var availableStatusText: String {
		switch driver.updateStage {
		case .downloaded: LauncherStrings.updateReady
		case .installing: LauncherStrings.updateInstalling
		default: LauncherStrings.updateAvailable
		}
	}

	private var statusColor: Color {
		switch driver.phase {
		case .failed: LauncherVisuals.dangerForeground
		case .installed: LauncherVisuals.success
		case .available, .downloading, .extracting, .readyToInstall, .installing:
			accentColor
		default: .secondary
		}
	}

	private var downloadProgress: Double {
		guard driver.expectedBytes > 0 else { return 0 }
		return min(Double(driver.receivedBytes) / Double(driver.expectedBytes), 1)
	}

	private var downloadProgressText: String {
		let received = DownloadProgressFormatting.byteCount(driver.receivedBytes)
		let expected = DownloadProgressFormatting.byteCount(driver.expectedBytes)
		return "\(received) / \(expected)"
	}

	private var percentageText: String {
		"\(Int(driver.extractionProgress * 100))%"
	}

	private var modalWidth: CGFloat {
		driver.phase == .available ? 700 : 620
	}

	private var modalHeight: CGFloat {
		guard contentHeight > 0 else { return driver.phase == .available ? 520 : 320 }
		return min(max(contentHeight + 160, 320), driver.phase == .available ? 600 : 430)
	}

	private func retryUpdate() {
		driver.acknowledge()
		Task { @MainActor in
			await Task.yield()
			checkForUpdates()
		}
	}
}
