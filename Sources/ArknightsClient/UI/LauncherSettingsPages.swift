// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct GeneralSettingsPage: View {
	@Bindable var model: LauncherViewModel

	var body: some View {
		SettingsPage(title: "General", subtitle: "Display and personalization") {
			SettingsPanel(title: "Display", systemImage: "rectangle.on.rectangle") {
				LabeledContent("High-resolution mode") {
					Toggle(
						"High-resolution mode",
						isOn: $model.launchOptions.usesHighResolutionMode
					)
					.labelsHidden()
					.toggleStyle(.switch)
					.tint(SettingsVisuals.cyan)
				}
				.help("Use the display's full pixel density without enlarging the game window")
				SettingsHairline()
				LabeledContent("Use in-game display settings") {
					Toggle(
						"Use in-game display settings",
						isOn: $model.launchOptions.usesGameSettings
					)
					.labelsHidden()
					.toggleStyle(.switch)
					.tint(SettingsVisuals.cyan)
				}
				.help("Lets changes made inside Arknights persist between launches")
				SettingsHairline()
				LabeledContent("Window Mode") {
					GlassMenuPicker(
						selection: $model.launchOptions.displayMode,
						options: GameDisplayMode.allCases.map { ($0, $0.displayName) },
						isDisabled: model.launchOptions.usesGameSettings
					)
				}
				.help("Overrides the game the next time it starts")
				SettingsHairline()
				LabeledContent("Resolution") {
					GlassMenuPicker(
						selection: $model.launchOptions.resolution,
						options: GameResolution.allCases.map { ($0, $0.displayName) },
						isDisabled: model.launchOptions.usesGameSettings
					)
				}
				.help("Overrides the game the next time it starts")
				SettingsHairline()
				LabeledContent("Metal Performance HUD") {
					Toggle(
						"Metal Performance HUD",
						isOn: $model.launchOptions.usesMetalPerformanceHUD
					)
					.labelsHidden()
					.toggleStyle(.switch)
					.tint(SettingsVisuals.cyan)
				}
				.help("Shows Apple's native FPS and GPU overlay the next time the game starts")
			}

			SettingsPanel(title: "Artwork", systemImage: "photo") {
				HStack {
					Text("Choose the image shown behind the launcher controls.")
						.foregroundStyle(.secondary)
					Spacer()
					Button("Choose…", action: model.chooseCustomArtwork)
					Button("Use Default", action: model.resetArtwork)
				}
			}
		}
	}
}

struct UpdatesSettingsPage: View {
	@Bindable var model: LauncherViewModel

	var body: some View {
		SettingsPage(title: "Updates", subtitle: "Keep the launcher and game current") {
			SettingsPanel(title: "Automatic Checks", systemImage: "arrow.trianglehead.2.clockwise")
			{
				UpdateSettingsRow(
					title: "Launcher",
					status: model.launcherUpdateStatus ?? "Not checked",
					isEnabled: $model.automaticallyChecksLauncherUpdates,
					isChecking: model.isCheckingLauncherUpdates,
					check: model.checkLauncherUpdates
				)
				SettingsHairline()
				UpdateSettingsRow(
					title: "Arknights",
					status: model.isGameUpdateAvailable ? "Update available" : model.versionText,
					isEnabled: $model.automaticallyChecksGameUpdates,
					isChecking: model.isDownloading,
					check: model.checkGameUpdates
				)
			}

			SettingsPanel(title: "Announcements", systemImage: "megaphone") {
				SettingsActionRow(
					title: "Announcements",
					detail: "Show occasional project messages once per announcement."
				) {
					Toggle("Announcements", isOn: $model.announcementsEnabled)
						.labelsHidden()
						.toggleStyle(.switch)
						.tint(SettingsVisuals.cyan)
				}
			}
		}
	}
}

#if DEBUG
	struct DeveloperSettingsPage: View {
		var model: LauncherViewModel

		var body: some View {
			SettingsPage(title: "Developer", subtitle: "Preview launcher states safely") {
				SettingsPanel(title: "Scenario", systemImage: "switch.2") {
					Picker("State", selection: scenarioBinding) {
						ForEach(DeveloperScenario.allCases) { scenario in
							Text(scenario.title).tag(scenario)
						}
					}
					.pickerStyle(.menu)
					SettingsHairline()
					Text(scenarioBinding.wrappedValue.detail)
						.foregroundStyle(.secondary)
				}

				SettingsPanel(title: "Isolation", systemImage: "lock.shield") {
					Text(
						"Game actions only move between simulated states. The preview uses separate temporary paths and preferences."
					)
					.foregroundStyle(.secondary)
				}
			}
		}

		private var scenarioBinding: Binding<DeveloperScenario> {
			Binding(
				get: { model.developerScenario ?? .ready },
				set: { scenario in model.applyDeveloperScenario(scenario) }
			)
		}
	}
#endif

struct InstallationSettingsPage: View {
	var model: LauncherViewModel
	@Binding var confirmsGameUninstall: Bool
	@Binding var confirmsForceMigration: Bool
	@State private var showsGameModeUnavailableAlert = false

	var body: some View {
		SettingsPage(title: "Installation", subtitle: "Files, repair, and removal") {
			SettingsPanel(title: "Region", systemImage: "globe") {
				LabeledContent("Region") {
					GlassMenuPicker(
						selection: regionBinding,
						options: GameRegion.allCases.map { ($0, $0.displayName) },
						isDisabled: !model.canSwitchRegion
					)
				}
				.help("Global, Japan, and Korea install, update, and launch independently")
			}

			SettingsPanel(title: "Location", systemImage: "externaldrive") {
				LabeledContent("Status") {
					Text(gameStatus)
						.foregroundStyle(model.isDownloading ? SettingsVisuals.cyan : .secondary)
				}
				SettingsHairline()
				LabeledContent("Folder") {
					HStack(spacing: 10) {
						Text(model.installDirectory.lastPathComponent)
							.lineLimit(1)
							.truncationMode(.middle)
							.help(model.installDirectory.path)
						Button("Show", systemImage: "folder", action: model.revealInstallDirectory)
							.labelStyle(.iconOnly)
							.disabled(!model.isInstalled)
							.help("Show game files in Finder")
					}
				}
				SettingsHairline()
				HStack {
					Menu("Installation Location", systemImage: "arrow.triangle.swap") {
						Button("Choose New Location…", action: model.chooseInstallDirectory)
						Button(
							"Locate Existing Installation…",
							action: model.locateExistingInstallation
						)
					}
					.disabled(model.isDownloading)
					Spacer()
				}
			}

			SettingsPanel(title: "Maintenance", systemImage: "wrench.and.screwdriver") {
				SettingsActionRow(
					title: "Repair",
					detail: "Check every game file and download missing or damaged files again."
				) {
					Button(
						"Repair…", systemImage: "wrench.and.screwdriver", action: model.repairGame
					)
					.disabled(!model.isInstalled || !model.canInstall)
				}
				SettingsHairline()
				SettingsActionRow(
					title: "Logs",
					detail: "Use these files when reporting startup or game problems."
				) {
					Button(
						"Show Logs", systemImage: "doc.text.magnifyingglass",
						action: model.revealLogs)
				}
				SettingsHairline()
				SettingsActionRow(
					title: "Report a Problem",
					detail: "Open a pre-filled bug report on GitHub."
				) {
					Button {
						NSWorkspace.shared.open(IssueReportURL.build())
					} label: {
						Label("Report…", systemImage: "ladybug")
					}
					.buttonStyle(.glass)
				}
			}

			DangerZonePanel {
				SettingsActionRow(
					title: "Game files",
					detail: "Move the selected game installation to the Trash."
				) {
					Button("Uninstall Game…", role: .destructive) {
						confirmsGameUninstall = true
					}
					.tint(SettingsVisuals.danger)
					.disabled(!model.isInstalled || model.isDownloading)
				}
				SettingsHairline()
				SettingsActionRow(
					title: "Wine Setup",
					detail:
						"Redo Wine initialization, DXMT installation, and registry overrides on the next launch. Game files and saves are untouched; only the next launch takes longer."
				) {
					Button("Force Migration…", role: .destructive) {
						confirmsForceMigration = true
					}
					.tint(SettingsVisuals.danger)
					.disabled(model.isDownloading || model.isGameActive)
				}
				SettingsHairline()
				SettingsActionRow(
					title: "Game Mode (Experimental)",
					detail:
						"Asks macOS to prioritize the game while it runs. Needs the full Xcode app installed, since only Xcode ships the tool this requires."
				) {
					Toggle("Game Mode", isOn: gameModeBinding)
						.labelsHidden()
						.toggleStyle(.switch)
						.tint(SettingsVisuals.danger)
				}
			}
		}
		.alert("Game Mode Needs Xcode", isPresented: $showsGameModeUnavailableAlert) {
			Button("OK") {}
		} message: {
			Text(
				"This requires Apple's gamepolicyctl tool, which only ships inside the full Xcode app, not the Command Line Tools. Install Xcode from the App Store to use it."
			)
		}
	}

	private var gameModeBinding: Binding<Bool> {
		Binding(
			get: { model.launchOptions.usesGameMode },
			set: { newValue in
				if newValue, !GamePolicyControl.isAvailable() {
					showsGameModeUnavailableAlert = true
					return
				}
				model.launchOptions.usesGameMode = newValue
			}
		)
	}

	private var gameStatus: String {
		if model.isDownloading, let progress = model.progress {
			return "Downloading \(Int(progress.fraction * 100))%"
		}
		if model.isDownloading { return "Preparing download" }
		if model.isInstalled { return "Installed" }
		return model.hasPartialDownload ? "Paused" : "Not installed"
	}

	private var regionBinding: Binding<GameRegion> {
		Binding(get: { model.region }, set: { model.selectRegion($0) })
	}
}

struct AboutSettingsPage: View {
	var model: LauncherViewModel
	@Binding var presentedDocument: BundledDocument?

	var body: some View {
		SettingsPage(title: "About", subtitle: "Arknights Client \(appVersion)") {
			HStack(alignment: .center, spacing: 18) {
				Image(nsImage: NSApplication.shared.applicationIconImage)
					.resizable()
					.frame(width: 76, height: 76)
				VStack(alignment: .leading, spacing: 5) {
					Text("Arknights Client")
						.font(.title2.bold())
					Text("Unofficial macOS launcher")
						.foregroundStyle(.secondary)
					CyanLink(
						title: "LuMiSxh", destination: URL(string: "https://github.com/LuMiSxh")!
					)
					.font(.callout.weight(.medium))
				}
				Spacer()
				Button("Show in Finder", systemImage: "folder", action: model.revealApplication)
					.labelStyle(.iconOnly)
					.buttonStyle(.glass)
					.help("Reveal the launcher application in Finder")
				Link(
					"GitHub Repository",
					destination: URL(
						string: "https://github.com/LuMiSxh/Arknights-MacOS-Client")!
				)
				.buttonStyle(.glass)
				.foregroundStyle(.primary)
			}
			.padding(20)
			.glassEffect(.regular, in: .rect(cornerRadius: 20))

			SettingsPanel(title: "Documents", systemImage: "doc.text") {
				DocumentLinkRow(title: "Changelog", systemImage: "clock.arrow.circlepath") {
					presentedDocument = .changelog
				}
				SettingsHairline()
				DocumentLinkRow(title: "MPL-2.0 License", systemImage: "checkmark.seal") {
					presentedDocument = .projectLicense
				}
				SettingsHairline()
				DocumentLinkRow(title: "Third-Party Notices", systemImage: "shippingbox") {
					presentedDocument = .thirdPartyNotices
				}
			}

			SettingsPanel(title: "Arknights", systemImage: "link") {
				HStack(spacing: 18) {
					if let agreement = model.branding?.userAgreement {
						CyanLink(title: "User Agreement", destination: agreement)
					}
					if let privacy = model.branding?.privacyPolicy {
						CyanLink(title: "Privacy Policy", destination: privacy)
					}
					Spacer()
					Text("This launcher is not affiliated with Hypergryph or Yostar.")
						.font(.caption)
						.foregroundStyle(.secondary)
				}
			}
		}
	}

	private var appVersion: String { IssueReportURL.appVersion }
}
