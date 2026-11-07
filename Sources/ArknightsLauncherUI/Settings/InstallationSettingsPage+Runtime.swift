// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameRuntime
import SwiftUI

extension InstallationSettingsPage {
	@ViewBuilder var runtimePanel: some View {
		SettingsPanel(title: "Runtime") {
			SettingsActionRow(
				title: "Architecture",
				detail: runtimeLaneTitle(runtimeSelection.selectedLane)
			) {
				EmptyView()
			}

			runtimeLaneRow(.x86)
			runtimeARMContent

			SettingsActionRow(
				title: "Other runtime",
				detail: runtimeOtherDetail
			) {
				CapsuleActionButton(
					title: "Remove Other Runtime",
					systemImage: "trash",
					tone: .neutral,
					presentation: .compact
				) {
					isRemoveRuntimeConfirmationPresented = true
				}
				.disabled(
					runtimeChangesDisabled || !runtimeOtherInstalled
						|| runtimeSelection.requiresRelaunch)
			}

			if runtimeSelection.isInstalling {
				RuntimeInstallStatusView(controller: runtimeSelection)
			}

			if let failure = runtimeSelection.failure {
				runtimeFailure(failure)
			}

			if runtimeSelection.requiresRelaunch {
				runtimeRelaunchNote
			}
		}
	}

	// MARK: - Lane rows

	private func runtimeLaneRow(_ lane: RuntimeLane) -> some View {
		SettingsActionRow(
			title: runtimeLaneTitle(lane),
			detail: runtimeLaneDetail(lane)
		) {
			if runtimeSelection.selectedLane == lane {
				Image(systemName: "checkmark.circle.fill")
					.foregroundStyle(theme.accentInk)
					.accessibilityLabel("Selected")
			} else if runtimeSelection.availableLanes.contains(lane) {
				CapsuleActionButton(
					title: "Switch to \(runtimeLaneShortLabel(lane))",
					systemImage: "arrow.triangle.swap",
					tone: .neutral,
					presentation: .compact
				) {
					pendingRuntimeLane = lane
				}
				.disabled(runtimeChangesDisabled)
			}
		}
	}

	@ViewBuilder private var runtimeARMContent: some View {
		if runtimeSelection.installedVersion(for: .arm) != nil {
			runtimeLaneRow(.arm)
			if !runtimeSelection.allowsARM64 {
				runtimeNote("ARM64 requires macOS 26 or later.")
			}
		} else if !runtimeSelection.allowsARM64 {
			runtimeNote("ARM64 requires macOS 26 or later.")
		} else if runtimeSelection.availableLanes.contains(.arm) {
			runtimeLaneRow(.arm)
		} else {
			runtimeNote("ARM64 is not available in this launcher release.")
		}
	}

	private func runtimeNote(_ text: String) -> some View {
		Text(text)
			.font(.caption)
			.foregroundStyle(theme.textSecondary)
			.fixedSize(horizontal: false, vertical: true)
	}

	// MARK: - Status and failure

	private func runtimeFailure(_ failure: RuntimeSelectionFailure) -> some View {
		VStack(alignment: .leading, spacing: LauncherTokens.Spacing.control) {
			Text(failure.message)
				.font(.callout)
				.foregroundStyle(theme.textPrimary)
				.fixedSize(horizontal: false, vertical: true)
			if let code = failure.code {
				HStack(spacing: LauncherTokens.Spacing.compact) {
					Text("Support code")
						.foregroundStyle(theme.textSecondary)
					Text(code.rawValue)
						.font(.callout.monospaced())
						.foregroundStyle(theme.dangerText)
						.textSelection(.enabled)
				}
				.font(.caption)
			}
		}
		.padding(.vertical, LauncherTokens.Spacing.compact)
	}

	private var runtimeRelaunchNote: some View {
		Text(
			"Quit and reopen the launcher to use \(runtimeLaneShortLabel(runtimeSelection.selectedLane))."
		)
		.font(.caption)
		.foregroundStyle(theme.textSecondary)
		.fixedSize(horizontal: false, vertical: true)
	}

	// MARK: - Switch confirmation

	var runtimeSwitchDialogTitle: String {
		guard let lane = pendingRuntimeLane else { return RuntimeSwitchWarning.title }
		return lane == .arm ? "Switch to ARM64?" : "Switch to x86_64?"
	}

	var runtimeSwitchButtonTitle: String {
		guard let lane = pendingRuntimeLane else { return "Switch" }
		return runtimeSelection.installedVersion(for: lane) == nil
			? "Switch and Download" : "Switch"
	}

	var runtimeSwitchMessage: String {
		guard let lane = pendingRuntimeLane, let pin = runtimeSelection.pinnedRuntime(for: lane)
		else { return RuntimeSwitchWarning.message }
		return RuntimeSwitchWarning.message(
			for: pin,
			isInstalled: runtimeSelection.installedVersion(for: lane) != nil
		)
	}

	func confirmRuntimeSwitch() {
		guard let lane = pendingRuntimeLane else { return }
		pendingRuntimeLane = nil
		if runtimeSelection.installedVersion(for: lane) == nil {
			Task { _ = await actions.installRuntime(lane) }
		} else {
			_ = actions.selectRuntimeLane(lane)
		}
	}

	// MARK: - Copy

	private var runtimeChangesDisabled: Bool {
		lifecycle.activity != .idle || runtimeSelection.isInstalling
	}

	private var runtimeOtherLane: RuntimeLane {
		runtimeSelection.selectedLane == .x86 ? .arm : .x86
	}

	private var runtimeOtherInstalled: Bool {
		runtimeSelection.installedVersion(for: runtimeOtherLane) != nil
	}

	private var runtimeOtherDetail: String {
		guard runtimeOtherInstalled else {
			return "No runtime is installed for the other architecture."
		}
		if runtimeSelection.requiresRelaunch {
			return "Quit and reopen the launcher before you remove the runtime this session uses."
		}
		return
			"Remove the \(runtimeLaneShortLabel(runtimeOtherLane)) runtime. Its game environment stays on disk."
	}

	private func runtimeLaneTitle(_ lane: RuntimeLane) -> String {
		lane == .x86 ? "x86_64 (recommended)" : "ARM64 (Apple Silicon)"
	}

	private func runtimeLaneShortLabel(_ lane: RuntimeLane) -> String {
		lane == .x86 ? "x86_64" : "ARM64"
	}

	private func runtimeLaneDetail(_ lane: RuntimeLane) -> String {
		var parts: [String] = []
		if let version = runtimeSelection.installedVersion(for: lane) {
			parts.append("Installed, version \(version)")
		} else if let pin = runtimeSelection.pinnedRuntime(for: lane) {
			parts.append("Not installed · Version \(pin.version)")
		} else {
			parts.append("Not installed")
		}
		guard let pin = runtimeSelection.pinnedRuntime(for: lane) else {
			return parts.joined(separator: " · ")
		}
		parts.append(
			"\(ByteCountFormatter.string(fromByteCount: Int64(pin.sizeBytes), countStyle: .file)) download"
		)
		parts.append("Requires \(macOSVersion(pin.minimumMacOS)) or later")
		return parts.joined(separator: " · ")
	}

	private func macOSVersion(_ version: OperatingSystemVersion) -> String {
		version.minorVersion == 0
			? "macOS \(version.majorVersion)"
			: "macOS \(version.majorVersion).\(version.minorVersion)"
	}
}

// Only this leaf reads the per-tick runtime progress, so the Settings page does not re-render
// on every update.
private struct RuntimeInstallStatusView: View {
	let controller: RuntimeSelectionController
	@Environment(\.launcherTheme) private var theme

	var body: some View {
		VStack(alignment: .leading, spacing: LauncherTokens.Spacing.control) {
			Text(title)
				.fontWeight(.medium)
			if let fraction = controller.installFraction {
				ProgressView(value: fraction)
					.tint(theme.accentFill)
			} else {
				ProgressView()
					.controlSize(.small)
			}
			if let detail {
				Text(detail)
					.font(.caption.monospacedDigit())
					.foregroundStyle(theme.textSecondary)
			}
		}
		.padding(.vertical, LauncherTokens.Spacing.compact)
	}

	private var title: String {
		guard let progress = controller.installProgress else { return "Preparing runtime…" }
		return switch progress.phase {
		case .downloading: "Downloading runtime…"
		case .extracting: "Extracting runtime…"
		case .validating: "Verifying runtime…"
		case .installing: "Installing runtime…"
		}
	}

	private var detail: String? {
		guard let progress = controller.installProgress, progress.phase == .downloading,
			progress.totalBytes > 0
		else { return nil }
		return
			"\(ByteCountFormatter.string(fromByteCount: progress.downloadedBytes, countStyle: .file)) of \(ByteCountFormatter.string(fromByteCount: progress.totalBytes, countStyle: .file))"
	}
}
