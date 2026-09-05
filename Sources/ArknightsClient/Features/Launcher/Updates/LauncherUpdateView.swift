// SPDX-License-Identifier: MPL-2.0

import AppKit
import SwiftUI

struct LauncherUpdateView: View {
	let driver: LauncherUpdateUserDriver
	let accentColor: Color
	let hudTintColor: Color
	let checkForUpdates: () -> Void
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var contentHeight: CGFloat = 0

	var body: some View {
		ThemedModalView(
			title: L10n.string(LauncherStrings.updateTitle),
			accentColor: accentColor,
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
		.animation(
			reduceMotion ? nil : .easeInOut(duration: 0.18),
			value: driver.phase
		)
	}

	private var statusHeader: some View {
		VStack(alignment: .leading, spacing: 6) {
			if let version = driver.version {
				Text(L10n.string(LauncherStrings.updateVersion(version)))
					.font(.headline)
			}
			Text(statusText)
				.foregroundStyle(.secondary)
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
				.accessibilityLabel(Text(L10n.string(LauncherStrings.updateChecking)))
		case .available:
			availableContent
		case .downloading:
			downloadContent
		case .extracting:
			extractionContent
		case .readyToInstall:
			Text(L10n.string(LauncherStrings.updateReadyDetail))
				.foregroundStyle(.secondary)
		case .installing:
			installingContent
		case .installed:
			Text(
				L10n.string(
					driver.relaunched
						? LauncherStrings.updateRelaunchDetail
						: LauncherStrings.updateInstalledDetail
				)
			)
			.foregroundStyle(.secondary)
		case .noUpdate:
			Text(L10n.string(LauncherStrings.updateNoUpdateDetail))
				.foregroundStyle(.secondary)
		case .failed:
			Text(driver.message ?? L10n.string(LauncherStrings.updateErrorDetail))
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
				Text(L10n.string(LauncherStrings.updateReleaseNotesUnavailable))
					.foregroundStyle(.secondary)
			}
			if driver.informationOnly {
				Text(L10n.string(LauncherStrings.updateInformationOnlyDetail))
					.foregroundStyle(.secondary)
			}
		}
	}

	private var downloadContent: some View {
		VStack(alignment: .leading, spacing: 10) {
			ProgressView(value: downloadProgress)
				.tint(accentColor)
				.accessibilityLabel(Text(L10n.string(LauncherStrings.updateDownloading)))
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
				.accessibilityLabel(Text(L10n.string(LauncherStrings.updateExtracting)))
				.accessibilityValue(Text(percentageText))
			Text(percentageText)
				.font(.caption.monospacedDigit())
				.foregroundStyle(.secondary)
		}
	}

	private var installingContent: some View {
		VStack(alignment: .leading, spacing: 10) {
			ProgressView()
				.accessibilityLabel(Text(L10n.string(LauncherStrings.updateInstalling)))
			Text(
				driver.message
					?? (driver.gameIsRunning
						? L10n.string(LauncherStrings.updateQuitDetail)
						: driver.terminationBlocked
							? L10n.string(LauncherStrings.updateWaitingDetail)
							: L10n.string(LauncherStrings.updateInstallingDetail))
			)
			.foregroundStyle(.secondary)
		}
	}

	@ViewBuilder
	private var actions: some View {
		switch driver.phase {
		case .checking:
			CapsuleActionButton(
				title: L10n.string(LauncherStrings.updateCancel),
				tone: .neutral,
				action: driver.cancelCheck
			)
		case .available:
			CapsuleActionButton(
				title: L10n.string(LauncherStrings.updateLater),
				tone: .neutral,
				action: { driver.choose(.dismiss) }
			)
			if driver.informationOnly {
				if let informationURL = driver.informationURL {
					CapsuleActionButton(
						title: L10n.string(LauncherStrings.updateMoreInformation),
						systemImage: "arrow.up.right",
						tone: .neutral
					) { NSWorkspace.shared.open(informationURL) }
				}
			} else {
				CapsuleActionButton(
					title: L10n.string(LauncherStrings.updateInstall),
					systemImage: "arrow.down.app",
					tone: .accent(accentColor),
					action: { driver.choose(.install) }
				)
			}
		case .downloading:
			CapsuleActionButton(
				title: L10n.string(LauncherStrings.updateCancel),
				tone: .neutral,
				action: driver.cancelDownload
			)
		case .extracting:
			EmptyView()
		case .readyToInstall:
			CapsuleActionButton(
				title: L10n.string(LauncherStrings.updateLater),
				tone: .neutral,
				action: { driver.choose(.dismiss) }
			)
			CapsuleActionButton(
				title: L10n.string(LauncherStrings.updateInstallNow),
				systemImage: "arrow.down.app",
				tone: .accent(accentColor),
				action: { driver.choose(.install) }
			)
		case .installing:
			if !driver.applicationTerminated {
				CapsuleActionButton(
					title: L10n.string(LauncherStrings.updateRetryQuit),
					systemImage: "arrow.clockwise",
					tone: .accent(accentColor),
					action: driver.retryTerminationRequest
				)
			}
		case .installed:
			CapsuleActionButton(
				title: L10n.string(LauncherStrings.updateDone),
				tone: .neutral,
				action: driver.acknowledge
			)
		case .noUpdate:
			CapsuleActionButton(
				title: L10n.string(LauncherStrings.updateCheckAgain),
				systemImage: "arrow.clockwise",
				tone: .accent(accentColor),
				action: retryUpdate
			)
			CapsuleActionButton(
				title: L10n.string(LauncherStrings.updateDone),
				tone: .neutral,
				action: driver.acknowledge
			)
		case .failed:
			CapsuleActionButton(
				title: L10n.string(LauncherStrings.updateTryAgain),
				systemImage: "arrow.clockwise",
				tone: .accent(accentColor),
				action: retryUpdate
			)
			CapsuleActionButton(
				title: L10n.string(LauncherStrings.updateDone),
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
		case .checking: L10n.string(LauncherStrings.updateChecking)
		case .available: availableStatusText
		case .downloading: L10n.string(LauncherStrings.updateDownloading)
		case .extracting: L10n.string(LauncherStrings.updateExtracting)
		case .readyToInstall: L10n.string(LauncherStrings.updateReady)
		case .installing: L10n.string(LauncherStrings.updateInstalling)
		case .installed: L10n.string(LauncherStrings.updateInstalled)
		case .noUpdate: L10n.string(LauncherStrings.updateNoUpdate)
		case .failed: L10n.string(LauncherStrings.updateFailed)
		}
	}

	private var availableStatusText: String {
		switch driver.updateStage {
		case .downloaded: L10n.string(LauncherStrings.updateReady)
		case .installing: L10n.string(LauncherStrings.updateInstalling)
		default: L10n.string(LauncherStrings.updateAvailable)
		}
	}

	private var downloadProgress: Double {
		guard driver.expectedBytes > 0 else { return 0 }
		return min(Double(driver.receivedBytes) / Double(driver.expectedBytes), 1)
	}

	private var downloadProgressText: String {
		let formatter = ByteCountFormatter()
		formatter.countStyle = .file
		let received = formatter.string(
			fromByteCount: Int64(min(driver.receivedBytes, UInt64(Int64.max))))
		let expected = formatter.string(
			fromByteCount: Int64(min(driver.expectedBytes, UInt64(Int64.max))))
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
