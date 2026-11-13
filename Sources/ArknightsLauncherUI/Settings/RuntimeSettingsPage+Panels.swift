// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameRuntime
import SwiftUI

extension RuntimeSettingsPage {
	// MARK: - Panels

	@ViewBuilder var activeRuntimePanel: some View {
		SettingsPanel(title: "Active runtime") {
			runtimeX86Content
			runtimeARMContent

			if let panelChangesReason {
				runtimeNote(panelChangesReason)
			}

			if runtimeSelection.isInstalling {
				RuntimeProgressLabel(controller: runtimeSelection)
				RuntimePauseButton(controller: runtimeSelection) {
					actions.pauseRuntimeDownload()
				}
			}

			if let failure = runtimeSelection.failure {
				runtimeFailure(failure)
			}

			QuietLink(title: "About game runtimes", destination: SupportLinks.runtimeGuide)
				.font(.caption)
		}
	}

	@ViewBuilder var maintenancePanel: some View {
		if isRuntimeUpdateAvailable || runtimeSelection.selectedLane == .x86 {
			maintenancePanelContent
		}
	}

	private var isRuntimeUpdateAvailable: Bool {
		if case .outdated = runtimeSelection.selectedLaneState { return true }
		return false
	}

	private var maintenancePanelContent: some View {
		SettingsPanel(title: "Maintenance") {
			runtimeUpdateContent

			if let panelChangesReason {
				runtimeNote(panelChangesReason)
			}

			if runtimeSelection.selectedLane == .x86 {
				SettingsActionRow(
					title: "Rosetta 2",
					detail: intelTranslation.statusDetail
						?? "Available. The x86_64 runtime can start."
				) {
					EmptyView()
				}
			}
		}
	}

	var removeRuntimePanel: some View {
		DangerZonePanel {
			SettingsActionRow(
				title: "Remove runtime",
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
			SettingsHairline()
			SettingsActionRow(
				title: "Remove other runtime",
				detail: runtimeOtherDetail
			) {
				CapsuleActionButton(
					title: "Remove Other Runtime…",
					systemImage: "trash",
					tone: .danger,
					presentation: .compact,
					role: .destructive
				) {
					isRemoveRuntimeConfirmationPresented = true
				}
				.disabled(runtimeChangesDisabled || !runtimeOtherInstalled)
			}
			if let panelChangesReason {
				runtimeNote(panelChangesReason)
			} else if runtimeSelection.installedVersion(for: runtimeSelection.selectedLane) == nil {
				runtimeNote("Install the runtime before you remove it.")
			}
		}
	}

	// MARK: - Lane rows

	private func runtimeLaneRow(_ lane: RuntimeLane) -> some View {
		SettingsActionRow(
			title: lane.title,
			detail: lane.summary,
			badge: lane == .arm ? "Recommended" : nil,
			secondaryDetail: runtimeSelection.pausedLane == lane
				? "Download paused" : runtimeLaneStatus(lane)
		) {
			if runtimeSelection.pausedLane == lane {
				CapsuleActionButton(
					title: "Resume",
					systemImage: "play.fill",
					tone: .accent,
					presentation: .compact
				) {
					Task { _ = await actions.installRuntime(lane) }
				}
				.disabled(runtimeChangesDisabled)
			} else if runtimeSelection.selectedLane == lane {
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
					if runtimeSelection.switchRequiresWarning {
						pendingRuntimeLane = lane
					} else {
						performRuntimeSwitch(to: lane)
					}
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
				title: "Runtime update",
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
		SettingsFootnote(text)
	}

	// MARK: - Status and failure

	private func runtimeFailure(_ failure: RuntimeSelectionFailure) -> some View {
		InlineFailureView(message: failure.message, code: failure.code)
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
		performRuntimeSwitch(to: lane)
	}

	private func performRuntimeSwitch(to lane: RuntimeLane) {
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
		if runtimeSelection.isInstalling { return "Wait for the download to finish." }
		return lifecycle.activity.lockReason
	}

	/// The game reason is in the page banner. Panels show the rest.
	private var panelChangesReason: String? {
		gameSession.isGameActive ? nil : runtimeChangesReason
	}

	var runtimeOtherLane: RuntimeLane {
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
			"Deletes the \(runtimeOtherLane.shortLabel) runtime you are not using. Its game environment stays on disk."
	}

	private func runtimeLaneStatus(_ lane: RuntimeLane) -> String {
		var parts: [String] = []
		let pin = runtimeSelection.pinnedRuntime(for: lane)
		switch runtimeSelection.state(for: lane) {
		case .notInstalled:
			parts.append("Not installed")
			if let pin {
				parts.append("Version \(pin.version)")
				parts.append(
					"\(ByteCountFormatter.string(fromByteCount: Int64(pin.sizeBytes), countStyle: .file)) download"
				)
			}
		case .outdated(let installed):
			if let pin {
				parts.append("Update available: \(pin.version) (installed \(installed))")
			} else {
				parts.append("Installed, version \(installed)")
			}
		case .current:
			if let installed = runtimeSelection.installedVersion(for: lane) {
				parts.append("Installed, version \(installed)")
			}
		}
		if let pin, !ProcessInfo.processInfo.isOperatingSystemAtLeast(pin.minimumMacOS) {
			parts.append("Requires \(macOSVersion(pin.minimumMacOS)) or later")
		}
		return parts.joined(separator: " · ")
	}

	private func macOSVersion(_ version: OperatingSystemVersion) -> String {
		version.minorVersion == 0
			? "macOS \(version.majorVersion)"
			: "macOS \(version.majorVersion).\(version.minorVersion)"
	}
}
