// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameInstallation
import ArknightsGameRuntime
import SwiftUI

extension RuntimeSettingsPage {
	// MARK: - Panels

	@ViewBuilder var activeRuntimePanel: some View {
		SettingsPanel(title: "Active runtime") {
			activeLaneRow

			if runtimeSelection.laneOverride != nil {
				runtimeNote(
					"You chose this runtime in the Danger zone. Set it to Automatic to let the launcher choose."
				)
			}

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

	@ViewBuilder var detailsPanel: some View {
		SettingsPanel(title: "Details") {
			detailRows
		}
	}

	private static let commitPrefixLength = 12

	@ViewBuilder private var detailRows: some View {
		if let runtime {
			SettingsActionRow(title: "Version") {
				valueText(runtime.name)
			}
			SettingsHairline()
			SettingsActionRow(title: "Architecture") {
				valueText(runtime.architecture)
			}
			SettingsHairline()
			// Not a stack: the panel pads and divides each top-level row, including the expanded ones.
			Group {
				Button {
					withAnimation(LauncherMotion.animation(.disclosure, reduceMotion: reduceMotion))
					{
						isShowingTechnicalDetails.toggle()
					}
				} label: {
					HStack {
						Text("Technical details")
							.foregroundStyle(theme.textPrimary)
						Spacer(minLength: 0)
						Image(systemName: "chevron.right")
							.font(.caption.weight(.medium))
							.foregroundStyle(theme.textSecondary)
							.rotationEffect(.degrees(isShowingTechnicalDetails ? 90 : 0))
							.accessibilityHidden(true)
					}
					.contentShape(.rect)
				}
				.buttonStyle(.plain)
				.accessibilityValue(isShowingTechnicalDetails ? "Expanded" : "Collapsed")
				if isShowingTechnicalDetails {
					SettingsHairline()
					SettingsActionRow(
						title: "Wine",
						detail: runtime.wineCommit.map {
							"Commit \($0.prefix(Self.commitPrefixLength))"
						}
					) {
						valueText(runtime.wineVersion ?? "—")
					}
					SettingsHairline()
					SettingsActionRow(
						title: "DXMT",
						detail: runtime.dxmtCommit.map {
							"Commit \($0.prefix(Self.commitPrefixLength))"
						}
					) {
						valueText(runtime.dxmtVersion ?? "—")
					}
					SettingsHairline()
					capabilityRow("Hardware cursor", advertised: runtime.hardwareCursor)
					SettingsHairline()
					capabilityRow(
						"MetalFX spatial upscaling", advertised: runtime.metalFXSpatialUpscaling)
					SettingsHairline()
					capabilityRow(
						"Native fullscreen Space", advertised: runtime.nativeFullscreenSpace)
				}
			}
		} else {
			SettingsActionRow(title: "Version") {
				valueText("Not installed")
			}
		}
	}

	private func capabilityRow(_ title: String, advertised: Bool) -> some View {
		SettingsActionRow(title: title) {
			valueText(advertised ? "Advertised" : "Not advertised")
		}
	}

	private func valueText(_ text: String) -> some View {
		Text(text)
			.foregroundStyle(theme.textSecondary)
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
			runtimeChoiceRow
			SettingsHairline()
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

	/// The lane the launcher chose. It has no picker: the Danger zone holds the override.
	private var activeLaneRow: some View {
		let lane = runtimeSelection.selectedLane
		let state = runtimeSelection.state(for: lane)
		return SettingsActionRow(
			title: lane.title,
			detail: lane.summary,
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
			} else if state == .notInstalled, !runtimeSelection.isInstalling {
				CapsuleActionButton(
					title: "Download",
					systemImage: "arrow.down",
					tone: .accent,
					presentation: .compact
				) {
					Task { _ = await actions.installRuntime(lane) }
				}
				.disabled(runtimeChangesDisabled)
			} else if state == .current {
				Image(systemName: "checkmark.circle.fill")
					.foregroundStyle(theme.accentInk)
					.accessibilityLabel("Installed")
			}
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

	func runtimeNote(_ text: String) -> some View {
		SettingsFootnote(text)
	}

	// MARK: - Status and failure

	private func runtimeFailure(_ failure: RuntimeSelectionFailure) -> some View {
		InlineFailureView(message: failure.message, code: failure.code)
	}

	// MARK: - Copy

	var runtimeChangesDisabled: Bool {
		lifecycle.activity != .idle || runtimeSelection.isInstalling
	}

	private var runtimeChangesReason: String? {
		if runtimeSelection.isInstalling { return "Wait for the download to finish." }
		return lifecycle.activity.lockReason
	}

	/// The game reason is in the page banner. Panels show the rest.
	var panelChangesReason: String? {
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
					"\(DownloadProgressFormatting.byteCount(Int64(pin.sizeBytes))) download"
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
			parts.append("Requires \(pin.minimumMacOS.macOSDisplayName) or later")
		}
		return parts.joined(separator: " · ")
	}
}
