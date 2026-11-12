// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameRuntime
import SwiftUI

extension InstallationSettingsPage {
	@ViewBuilder var runtimePanel: some View {
		SettingsPanel(title: "Runtime") {
			SettingsActionRow(
				title: "Runtime",
				detail: runtimeSelection.selectedLane.title
			) {
				EmptyView()
			}

			runtimeX86Content
			runtimeARMContent
			runtimeUpdateContent

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
					runtimeChangesDisabled || !runtimeOtherInstalled)
			}

			SettingsActionRow(
				title: "Remove Runtime",
				detail:
					"Delete the \(runtimeSelection.selectedLane.shortLabel) runtime. The game environment stays."
			) {
				CapsuleActionButton(
					title: "Remove Runtime…",
					systemImage: "trash",
					tone: .danger,
					presentation: .compact,
					role: .destructive
				) {
					isRemoveSelectedRuntimeConfirmationPresented = true
				}
				.disabled(
					runtimeChangesDisabled
						|| runtimeSelection.installedVersion(
							for: runtimeSelection.selectedLane) == nil
				)
			}

			if let runtimeChangesReason {
				runtimeNote(runtimeChangesReason)
			}

			if runtimeSelection.isInstalling {
				RuntimeProgressLabel(controller: runtimeSelection)
			}

			if let failure = runtimeSelection.failure {
				runtimeFailure(failure)
			}

			QuietLink(title: "About game runtimes", destination: SupportLinks.runtimeGuide)
				.font(.caption)
		}
	}

	// MARK: - Lane rows

	private func runtimeLaneRow(_ lane: RuntimeLane) -> some View {
		SettingsActionRow(
			title: lane.title,
			detail: runtimeLaneDetail(lane)
		) {
			if runtimeSelection.selectedLane == lane {
				Image(systemName: "checkmark.circle.fill")
					.foregroundStyle(theme.accentInk)
					.accessibilityLabel("Selected")
			} else if runtimeSelection.availableLanes.contains(lane) {
				CapsuleActionButton(
					title: "Switch to \(lane.shortLabel)",
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

	@ViewBuilder private var runtimeX86Content: some View {
		let showsLane =
			runtimeSelection.installedVersion(for: .x86) != nil
			|| (runtimeSelection.allowsX86 && runtimeSelection.availableLanes.contains(.x86))
		if showsLane { runtimeLaneRow(.x86) }
		if !runtimeSelection.allowsX86 {
			runtimeNote("x86_64 requires macOS 27 or earlier.")
		} else if !showsLane {
			runtimeNote("x86_64 is not available in this launcher release.")
		}
	}

	@ViewBuilder private var runtimeARMContent: some View {
		let showsLane =
			runtimeSelection.installedVersion(for: .arm) != nil
			|| (runtimeSelection.allowsARM64 && runtimeSelection.availableLanes.contains(.arm))
		if showsLane { runtimeLaneRow(.arm) }
		if !runtimeSelection.allowsARM64 {
			runtimeNote("ARM64 requires macOS 26 or later.")
		} else if !showsLane {
			runtimeNote("ARM64 is not available in this launcher release.")
		}
	}

	@ViewBuilder private var runtimeUpdateContent: some View {
		if case .outdated(let installed) = runtimeSelection.selectedLaneState,
			let pin = runtimeSelection.pinnedRuntime(for: runtimeSelection.selectedLane)
		{
			SettingsActionRow(
				title: "Update Runtime",
				detail: "Update available: \(pin.version) (installed \(installed))"
			) {
				CapsuleActionButton(
					title: "Update Runtime",
					systemImage: "arrow.down",
					tone: .accent,
					presentation: .compact
				) {
					Task { _ = await actions.installRuntime(runtimeSelection.selectedLane) }
				}
				.disabled(runtimeChangesDisabled)
			}
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

	// MARK: - Switch confirmation

	var runtimeSwitchDialogTitle: String {
		guard let lane = pendingRuntimeLane else { return RuntimeSwitchWarning.title }
		return lane == .arm ? "Switch to ARM64?" : "Switch to x86_64?"
	}

	var runtimeSwitchButtonTitle: String {
		guard let lane = pendingRuntimeLane else { return "Switch" }
		return runtimeSelection.state(for: lane) == .current
			? "Switch" : "Switch and Download"
	}

	var runtimeSwitchMessage: String {
		guard let lane = pendingRuntimeLane, let pin = runtimeSelection.pinnedRuntime(for: lane)
		else { return RuntimeSwitchWarning.message }
		return RuntimeSwitchWarning.message(
			for: pin,
			isInstalled: runtimeSelection.state(for: lane) == .current
		)
	}

	func confirmRuntimeSwitch() {
		guard let lane = pendingRuntimeLane else { return }
		pendingRuntimeLane = nil
		if runtimeSelection.state(for: lane) == .current {
			_ = actions.selectRuntimeLane(lane)
		} else {
			Task { _ = await actions.installRuntime(lane) }
		}
	}

	// MARK: - Copy

	private var runtimeChangesDisabled: Bool {
		lifecycle.activity != .idle || runtimeSelection.isInstalling
	}

	private var runtimeChangesReason: String? {
		if runtimeSelection.isInstalling || lifecycle.activity.isInstalling {
			return "Wait for the current download to finish."
		}
		if lifecycle.activity.isGameActive {
			return "Quit the game to change the runtime."
		}
		return nil
	}

	private var runtimeOtherLane: RuntimeLane {
		runtimeSelection.selectedLane == .x86 ? .arm : .x86
	}

	private var runtimeOtherInstalled: Bool {
		runtimeSelection.installedVersion(for: runtimeOtherLane) != nil
	}

	private var runtimeOtherDetail: String {
		guard runtimeOtherInstalled else {
			return "No other runtime is installed."
		}
		return
			"Remove the \(runtimeOtherLane.shortLabel) runtime. Its game environment stays on disk."
	}

	private func runtimeLaneDetail(_ lane: RuntimeLane) -> String {
		let headline = lane == .arm ? "Recommended. \(lane.summary)" : lane.summary
		return "\(headline) \(runtimeLaneInfo(lane))"
	}

	private func runtimeLaneInfo(_ lane: RuntimeLane) -> String {
		var parts: [String] = []
		switch runtimeSelection.state(for: lane) {
		case .notInstalled:
			if let pin = runtimeSelection.pinnedRuntime(for: lane) {
				parts.append("Not installed · Version \(pin.version)")
			} else {
				parts.append("Not installed")
			}
		case .outdated(let installed):
			if let pin = runtimeSelection.pinnedRuntime(for: lane) {
				parts.append("Update available: \(pin.version) (installed \(installed))")
			} else {
				parts.append("Installed, version \(installed)")
			}
		case .current:
			if let installed = runtimeSelection.installedVersion(for: lane) {
				parts.append("Installed, version \(installed)")
			}
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
