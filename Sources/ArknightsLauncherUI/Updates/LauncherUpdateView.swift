// SPDX-License-Identifier: MPL-2.0

import AppKit
import ArknightsCore
import ArknightsGameInstallation
import SwiftUI

struct LauncherUpdateView: View {
	@Environment(\.launcherTheme) private var theme
	private static let installingTitle = "Finishing update…"

	let driver: LauncherUpdateUserDriver

	let checkForUpdates: () -> Void
	@State private var contentHeight: CGFloat = 0

	var body: some View {
		ThemedModalView(
			title: "Launcher Update",

			width: modalWidth,
			height: modalHeight
		) {
			VStack(alignment: .leading, spacing: LauncherTokens.Spacing.panel) {
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
		VStack(alignment: .leading, spacing: LauncherTokens.Spacing.control) {
			if let version = driver.version {
				Text("Version \(version)")
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
				.accessibilityLabel(Text("Checking for updates…"))
		case .available:
			availableContent
		case .downloading:
			downloadContent
		case .extracting:
			extractionContent
		case .readyToInstall:
			Text("The update can be installed now.")
				.foregroundStyle(theme.textSecondary)
		case .installing:
			installingContent
		case .installed:
			Text("The update was installed.")
				.foregroundStyle(theme.textSecondary)
		case .noUpdate:
			Text("No newer version was found.")
				.foregroundStyle(theme.textSecondary)
		case .failed:
			Text(driver.message ?? LauncherUpdateUserDriver.errorDetail)
				.foregroundStyle(theme.textSecondary)
				.textSelection(.enabled)
		}
	}

	private var availableContent: some View {
		VStack(alignment: .leading, spacing: LauncherTokens.Spacing.content) {
			if let releaseNotes = driver.releaseNotes, !releaseNotes.isEmpty {
				if driver.releaseNotesFormat == "markdown" {
					MarkdownDocument(source: releaseNotes)
				} else {
					Text(releaseNotes)
						.textSelection(.enabled)
				}
			} else {
				Text("Release notes are unavailable.")
					.foregroundStyle(theme.textSecondary)
			}
			if driver.informationOnly {
				Text("This version is informational only and cannot be installed by the launcher.")
					.foregroundStyle(theme.textSecondary)
			}
		}
	}

	private var downloadContent: some View {
		VStack(alignment: .leading, spacing: LauncherTokens.Spacing.control) {
			ProgressView(value: downloadProgress)
				.tint(theme.accentFill)
				.accessibilityLabel(Text("Downloading update…"))
				.accessibilityValue(Text(downloadProgressText))
			Text(downloadProgressText)
				.font(.caption.monospacedDigit())
				.foregroundStyle(theme.textSecondary)
		}
	}

	private var extractionContent: some View {
		VStack(alignment: .leading, spacing: LauncherTokens.Spacing.control) {
			ProgressView(value: driver.extractionProgress)
				.tint(theme.accentFill)
				.accessibilityLabel(Text("Preparing update…"))
				.accessibilityValue(Text(percentageText))
			Text(percentageText)
				.font(.caption.monospacedDigit())
				.foregroundStyle(theme.textSecondary)
		}
	}

	private var installingContent: some View {
		VStack(alignment: .leading, spacing: LauncherTokens.Spacing.control) {
			ProgressView()
				.accessibilityLabel(Text(Self.installingTitle))
			Text(
				driver.message
					?? (driver.gameIsRunning
						? "Close the game to finish the launcher update. Installation continues automatically afterward."
						: driver.terminationBlocked
							? "The launcher is waiting for its current activity to finish."
							: "The launcher will close and reopen automatically to finish the update.")
			)
			.foregroundStyle(theme.textSecondary)
		}
	}

	@ViewBuilder
	private var actions: some View {
		switch driver.phase {
		case .checking:
			CapsuleActionButton(
				title: "Cancel",
				tone: .neutral,
				action: driver.cancelCheck
			)
		case .available:
			CapsuleActionButton(
				title: "Later",
				tone: .neutral,
				action: { driver.choose(.dismiss) }
			)
			if driver.informationOnly {
				if let informationURL = driver.informationURL {
					CapsuleActionButton(
						title: "More Information",
						systemImage: "arrow.up.right",
						tone: .neutral
					) { NSWorkspace.shared.open(informationURL) }
				}
			} else {
				CapsuleActionButton(
					title: "Install Update",
					systemImage: "arrow.down.app",
					tone: .accent,
					action: { driver.choose(.install) }
				)
				.keyboardShortcut(.defaultAction)
			}
		case .downloading:
			CapsuleActionButton(
				title: "Cancel",
				tone: .neutral,
				action: driver.cancelDownload
			)
		case .extracting:
			EmptyView()
		case .readyToInstall:
			CapsuleActionButton(
				title: "Later",
				tone: .neutral,
				action: { driver.choose(.dismiss) }
			)
			CapsuleActionButton(
				title: "Install Update",
				systemImage: "arrow.down.app",
				tone: .accent,
				action: { driver.choose(.install) }
			)
			.keyboardShortcut(.defaultAction)
		case .installing:
			if !driver.applicationTerminated {
				CapsuleActionButton(
					title: "Try Quitting Again",
					systemImage: "arrow.clockwise",
					tone: .neutral,
					action: driver.retryTerminationRequest
				)
			}
		case .installed:
			CapsuleActionButton(
				title: "Done",
				tone: .neutral,
				action: driver.acknowledge
			)
		case .noUpdate:
			CapsuleActionButton(
				title: "Check Again",
				systemImage: "arrow.clockwise",
				tone: .neutral,
				action: retryUpdate
			)
			CapsuleActionButton(
				title: "Done",
				tone: .neutral,
				action: driver.acknowledge
			)
		case .failed:
			CapsuleActionButton(
				title: "Try Again",
				systemImage: "arrow.clockwise",
				tone: .accent,
				action: retryUpdate
			)
			.keyboardShortcut(.defaultAction)
			CapsuleActionButton(
				title: "Done",
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
		case .checking: "Checking for updates…"
		case .available: availableStatusText
		case .downloading: "Downloading update…"
		case .extracting: "Preparing update…"
		case .readyToInstall: "Update is ready."
		case .installing: Self.installingTitle
		case .installed: "Update installed"
		case .noUpdate: "The launcher is up to date."
		case .failed: "Couldn’t check for updates"
		}
	}

	private var availableStatusText: String {
		switch driver.updateStage {
		case .downloaded: "Update is ready."
		case .installing: Self.installingTitle
		default: "An update is available."
		}
	}

	private var statusColor: Color {
		switch driver.phase {
		case .failed: theme.danger
		case .installed: theme.successInk
		default: theme.textSecondary
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
