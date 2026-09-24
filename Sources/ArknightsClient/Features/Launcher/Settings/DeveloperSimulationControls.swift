// SPDX-License-Identifier: MPL-2.0

import SwiftUI

#if DEBUG
	/// Directly composable debug controls for launcher presentation states.
	struct DeveloperSimulationControls: View {
		@Binding var simulation: DeveloperSimulationState
		let accentColor: Color

		var body: some View {
			lifecyclePanel
			progressPanel
			launcherPanel
			regionPanel
			chromePanel
			accessibilityPanel
		}

		private var lifecyclePanel: some View {
			SettingsPanel(title: "Launcher state", systemImage: "play.circle") {
				SettingsActionRow(
					title: "Lifecycle", detail: "Choose the visible launcher activity."
				) {
					GlassMenuPicker(
						selection: $simulation.lifecycle,
						options: DeveloperPreviewLifecycle.allCases.map { ($0, $0.title) },
						accentColor: accentColor
					)
				}
				SettingsHairline()
				SettingsActionRow(
					title: "Installation", detail: "Combine readiness and partial-file states."
				) {
					VStack(alignment: .trailing, spacing: LauncherVisuals.Spacing.compact) {
						labeledToggle("Installed", isOn: selectedInstallationBinding)
						labeledToggle("Partial download", isOn: $simulation.hasPartialDownload)
					}
				}
				SettingsHairline()
				SettingsActionRow(
					title: "Installation phase", detail: "Used while lifecycle is Installing."
				) {
					GlassMenuPicker(
						selection: $simulation.installationPhase,
						options: DeveloperPreviewInstallationPhase.allCases.map { ($0, $0.title) },
						accentColor: accentColor,
						isDisabled: simulation.lifecycle != .installing
					)
				}
				SettingsHairline()
				SettingsActionRow(
					title: "Game update",
					detail: "Expose an update without changing installation readiness."
				) {
					SettingsToggle(
						"Update available",
						isOn: $simulation.updateAvailable,
						accentColor: accentColor
					)
				}
			}
		}

		private var progressPanel: some View {
			SettingsPanel(title: "Download progress", systemImage: "arrow.down.circle") {
				SettingsActionRow(
					title: "Values",
					detail: "Show a known progress model or an indeterminate state."
				) {
					GlassMenuPicker(
						selection: $simulation.progressMode,
						options: DeveloperPreviewProgressMode.allCases.map { ($0, $0.title) },
						accentColor: accentColor
					)
				}
				SettingsHairline()
				SettingsActionRow(
					title: "Percent", detail: "The progress bar's fraction from 0 to 100."
				) {
					HStack(spacing: LauncherVisuals.Spacing.control) {
						SettingsSlider(
							value: $simulation.progressPercent,
							range: 0...1,
							step: 0.01,
							accentColor: accentColor,
							width: 130
						)
						Text("\(Int(simulation.progressPercent * 100))%")
							.monospacedDigit()
							.frame(width: 42, alignment: .trailing)
					}
					.accessibilityElement(children: .combine)
					.accessibilityLabel("Download progress")
					.accessibilityValue("\(Int(simulation.progressPercent * 100)) percent")
				}
				.disabled(simulation.progressMode == .unknown)
				SettingsHairline()
				SettingsActionRow(
					title: "Transfer speed",
					detail: "Exercise known, unknown, and stalled transfer states."
				) {
					VStack(alignment: .trailing, spacing: LauncherVisuals.Spacing.compact) {
						GlassMenuPicker(
							selection: $simulation.transferRateMode,
							options: DeveloperPreviewTransferRateMode.allCases.map {
								($0, $0.title)
							},
							accentColor: accentColor
						)
						if simulation.transferRateMode == .known {
							HStack(spacing: LauncherVisuals.Spacing.compact) {
								SettingsSlider(
									value: transferRateMegabytes,
									range: 0...50,
									step: 0.1,
									accentColor: accentColor,
									width: 130
								)
								.accessibilityLabel("Transfer speed")
								.accessibilityValue(
									"\(simulation.transferRateBytesPerSecond / 1_000_000, specifier: "%.1f") megabytes per second"
								)
								Text(
									"\(simulation.transferRateBytesPerSecond / 1_000_000, specifier: "%.1f") MB/s"
								)
								.monospacedDigit()
							}
						}
						labeledToggle("Stalled", isOn: $simulation.transferStalled)
					}
				}
				SettingsHairline()
				SettingsActionRow(
					title: "Transfer values",
					detail: "Use representative byte and file counts in the detail line."
				) {
					HStack(spacing: LauncherVisuals.Spacing.control) {
						VStack(alignment: .leading, spacing: LauncherVisuals.Spacing.compact) {
							Text("Downloaded bytes").font(.caption).foregroundStyle(.secondary)
							ThemedTextField(
								"Downloaded bytes", prompt: "Downloaded", text: downloadedBytesText,
								accentColor: accentColor)
						}
						VStack(alignment: .leading, spacing: LauncherVisuals.Spacing.compact) {
							Text("Total bytes").font(.caption).foregroundStyle(.secondary)
							ThemedTextField(
								"Total bytes", prompt: "Total", text: totalBytesText,
								accentColor: accentColor)
						}
					}
					.frame(maxWidth: 330)
				}
				.disabled(simulation.progressMode == .unknown)
				SettingsActionRow(
					title: "File counts", detail: "Exercise short and long file-count labels."
				) {
					HStack(spacing: LauncherVisuals.Spacing.control) {
						VStack(alignment: .leading, spacing: LauncherVisuals.Spacing.compact) {
							Text("Completed files").font(.caption).foregroundStyle(.secondary)
							ThemedTextField(
								"Completed files", prompt: "Completed", text: completedFilesText,
								accentColor: accentColor)
						}
						VStack(alignment: .leading, spacing: LauncherVisuals.Spacing.compact) {
							Text("Total files").font(.caption).foregroundStyle(.secondary)
							ThemedTextField(
								"Total files", prompt: "Total", text: totalFilesText,
								accentColor: accentColor)
						}
					}
					.frame(maxWidth: 330)
				}
				.disabled(simulation.progressMode == .unknown)
				VStack(alignment: .leading, spacing: LauncherVisuals.Spacing.compact) {
					Text("Current file").font(.caption).foregroundStyle(.secondary)
					ThemedTextField(
						"Current file",
						prompt: "Current file path",
						text: $simulation.currentFile,
						systemImage: "doc",
						accentColor: accentColor
					)
				}
				.disabled(simulation.progressMode == .unknown)
			}
		}

		private var launcherPanel: some View {
			SettingsPanel(title: "Launcher and support", systemImage: "wrench.and.screwdriver") {
				SettingsActionRow(
					title: "Launcher update", detail: "Set the update check result independently."
				) {
					GlassMenuPicker(
						selection: $simulation.launcherUpdate,
						options: DeveloperPreviewLauncherUpdate.allCases.map { ($0, $0.title) },
						accentColor: accentColor
					)
				}
				SettingsHairline()
				SettingsActionRow(
					title: "Failure",
					detail: "Inject a support surface without running a real operation."
				) {
					GlassMenuPicker(
						selection: $simulation.failure,
						options: DeveloperPreviewFailure.allCases.map { ($0, $0.title) },
						accentColor: accentColor
					)
				}
				SettingsActionRow(
					title: "Support code", detail: "Use any published support identifier."
				) {
					GlassMenuPicker(
						selection: $simulation.failureCode,
						options: SupportCode.allCases.map { ($0, $0.rawValue) },
						accentColor: accentColor,
						isDisabled: simulation.failure == .none
					)
				}
			}
		}

		private var regionPanel: some View {
			SettingsPanel(title: "Regions", systemImage: "globe") {
				SettingsActionRow(
					title: "Selected region",
					detail: "The existing region availability rules stay in control."
				) {
					GlassMenuPicker(
						selection: selectedRegionBinding,
						options: simulation.selectableRegions.map { ($0, $0.displayName) },
						accentColor: accentColor
					)
				}
				SettingsHairline()
				SettingsActionRow(
					title: "Canary clients",
					detail: "Reveal Taiwan and China options through the production flags."
				) {
					SettingsToggle(
						"Canary features",
						isOn: $simulation.canaryFeaturesEnabled,
						accentColor: accentColor
					)
				}
				SettingsActionRow(
					title: "China clients", detail: "Allow both China client entries in the picker."
				) {
					SettingsToggle(
						"China clients",
						isOn: $simulation.chinaClientsEnabled,
						accentColor: accentColor
					)
				}
				SettingsActionRow(
					title: "Taiwan client", detail: "Allow the Taiwan client entry in the picker."
				) {
					SettingsToggle(
						"Taiwan client",
						isOn: $simulation.taiwanClientEnabled,
						accentColor: accentColor
					)
				}
				SettingsHairline()
				ForEach(simulation.selectableRegions) { region in
					SettingsActionRow(
						title: region.displayName, detail: "Installed state for this region."
					) {
						labeledToggle("Installed", isOn: regionBinding(region))
					}
				}
			}
		}

		private var chromePanel: some View {
			SettingsPanel(title: "HUD and popups", systemImage: "rectangle.topthird.inset.filled") {
				SettingsActionRow(
					title: "Status pill", detail: "Show the server reset countdown pill."
				) {
					SettingsToggle(
						"Status", isOn: $simulation.showStatusPill, accentColor: accentColor)
				}
				SettingsActionRow(
					title: "Version pill", detail: "Show the installed game version pill."
				) {
					SettingsToggle(
						"Version", isOn: $simulation.showVersionPill, accentColor: accentColor)
				}
				SettingsActionRow(
					title: "Music pill", detail: "Show the current track pill when a track exists."
				) {
					SettingsToggle(
						"Music", isOn: $simulation.showMusicPill, accentColor: accentColor)
				}
				SettingsActionRow(
					title: "Expanded pill", detail: "Open one available pill on the launcher HUD."
				) {
					GlassMenuPicker(
						selection: $simulation.expandedPill,
						options: DeveloperPreviewPill.allCases.map { ($0, $0.title) },
						accentColor: accentColor
					)
				}
				SettingsHairline()
				SettingsActionRow(
					title: "Popup", detail: "Inject an announcement or custom Markdown popup."
				) {
					GlassMenuPicker(
						selection: $simulation.popup,
						options: DeveloperPreviewPopup.allCases.map { ($0, $0.title) },
						accentColor: accentColor
					)
				}
			}
		}

		private var accessibilityPanel: some View {
			SettingsPanel(title: "Accessibility and presentation", systemImage: "accessibility") {
				SettingsActionRow(
					title: "Dynamic theme", detail: "Keep artwork-derived tinting on or off."
				) {
					SettingsToggle(
						"Dynamic theme", isOn: $simulation.usesDynamicTheme,
						accentColor: accentColor)
				}
				SettingsActionRow(
					title: "Long accessibility labels",
					detail: "Exercise text expansion in the music pill."
				) {
					SettingsToggle(
						"Long labels", isOn: $simulation.longAccessibilityText,
						accentColor: accentColor)
				}
				SettingsActionRow(
					title: "Onboarding preview",
					detail: "Open the onboarding surface inside the debug path."
				) {
					SettingsToggle(
						"Onboarding", isOn: $simulation.onboardingPreview, accentColor: accentColor)
				}
				SettingsActionRow(
					title: "Rosetta unavailable",
					detail: "Show the translation recovery state without installing anything."
				) {
					SettingsToggle(
						"Rosetta missing", isOn: $simulation.rosettaMissing,
						accentColor: accentColor)
				}
			}
		}

		private func regionBinding(_ region: GameRegion) -> Binding<Bool> {
			Binding(
				get: { simulation.installedRegions.contains(region) },
				set: { isInstalled in
					if isInstalled {
						simulation.installedRegions.insert(region)
					} else {
						simulation.installedRegions.remove(region)
					}
					if region == simulation.selectedRegion {
						simulation.isInstalled = isInstalled
					}
				}
			)
		}
		private var selectedInstallationBinding: Binding<Bool> {
			Binding(
				get: { simulation.isInstalled },
				set: { isInstalled in
					simulation.isInstalled = isInstalled
					if isInstalled {
						simulation.installedRegions.insert(simulation.selectedRegion)
					} else {
						simulation.installedRegions.remove(simulation.selectedRegion)
					}
				}
			)
		}
		private var selectedRegionBinding: Binding<GameRegion> {
			Binding(
				get: { simulation.selectedRegion },
				set: { region in
					simulation.selectedRegion = region
					simulation.isInstalled = simulation.installedRegions.contains(region)
				}
			)
		}
		private func labeledToggle(_ title: String, isOn: Binding<Bool>) -> some View {
			HStack(spacing: LauncherVisuals.Spacing.compact) {
				Text(title)
					.font(.callout)
					.foregroundStyle(.secondary)
				SettingsToggle(title, isOn: isOn, accentColor: accentColor)
			}
			.accessibilityElement(children: .combine)
			.accessibilityLabel(title)
		}
		private var transferRateMegabytes: Binding<Double> {
			Binding(
				get: { simulation.transferRateBytesPerSecond / 1_000_000 },
				set: { simulation.transferRateBytesPerSecond = max($0, 0) * 1_000_000 }
			)
		}
		private var downloadedBytesText: Binding<String> {
			integerBinding(
				get: { simulation.downloadedBytes },
				set: { simulation.downloadedBytes = max($0, 0) }
			)
		}
		private var totalBytesText: Binding<String> {
			integerBinding(
				get: { simulation.totalBytes },
				set: { simulation.totalBytes = max($0, 1) }
			)
		}
		private var completedFilesText: Binding<String> {
			integerBinding(
				get: { Int64(simulation.completedFiles) },
				set: { simulation.completedFiles = Int($0) }
			)
		}
		private var totalFilesText: Binding<String> {
			integerBinding(
				get: { Int64(simulation.totalFiles) },
				set: { simulation.totalFiles = Int($0) }
			)
		}
		private func integerBinding(
			get: @escaping () -> Int64,
			set: @escaping (Int64) -> Void
		) -> Binding<String> {
			Binding(
				get: { String(get()) },
				set: { value in
					guard let parsed = Int64(value) else { return }
					set(parsed)
				}
			)
		}
	}
#endif
