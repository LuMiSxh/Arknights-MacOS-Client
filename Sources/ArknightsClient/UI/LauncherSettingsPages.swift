// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct GeneralSettingsPage: View {
	@ObservedObject var model: LauncherViewModel

	var body: some View {
		SettingsPage(title: "General", subtitle: "Game display, updates, and artwork") {
			SettingsPanel(title: "Display", systemImage: "rectangle.on.rectangle") {
				Toggle(
					"High-resolution mode",
					isOn: $model.launchOptions.usesHighResolutionMode
				)
				.toggleStyle(.switch)
				.tint(SettingsVisuals.cyan)
				.help("Use the display's full pixel density without enlarging the game window")
				Divider()
				Toggle("Use in-game display settings", isOn: $model.launchOptions.usesGameSettings)
					.toggleStyle(.switch)
					.tint(SettingsVisuals.cyan)
					.help("Lets changes made inside Arknights persist between launches")
				Divider()
				Picker("Window Mode", selection: $model.launchOptions.displayMode) {
					ForEach(GameDisplayMode.allCases, id: \.self) { mode in
						Text(mode.displayName).tag(mode)
					}
				}
				.disabled(model.launchOptions.usesGameSettings)
				.help("Overrides the game the next time it starts")
				Picker("Resolution", selection: $model.launchOptions.resolution) {
					ForEach(GameResolution.allCases, id: \.self) { resolution in
						Text(resolution.displayName).tag(resolution)
					}
				}
				.disabled(model.launchOptions.usesGameSettings)
				.help("Overrides the game the next time it starts")
			}

			SettingsPanel(title: "Updates", systemImage: "arrow.trianglehead.2.clockwise") {
				UpdateSettingsRow(
					title: "Launcher",
					status: model.launcherUpdateStatus ?? "Not checked",
					isEnabled: $model.automaticallyChecksLauncherUpdates,
					isChecking: model.isCheckingLauncherUpdates,
					check: model.checkLauncherUpdates
				)
				Divider()
				UpdateSettingsRow(
					title: "Arknights",
					status: model.isGameUpdateAvailable ? "Update available" : model.versionText,
					isEnabled: $model.automaticallyChecksGameUpdates,
					isChecking: model.isDownloading,
					check: model.checkGameUpdates
				)
				Divider()
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

#if DEBUG
	struct DeveloperSettingsPage: View {
		@ObservedObject var model: LauncherViewModel

		var body: some View {
			SettingsPage(title: "Developer", subtitle: "Preview launcher states safely") {
				SettingsPanel(title: "Scenario", systemImage: "switch.2") {
					Picker("State", selection: scenarioBinding) {
						ForEach(DeveloperScenario.allCases) { scenario in
							Text(scenario.title).tag(scenario)
						}
					}
					.pickerStyle(.menu)
					Divider()
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
	@ObservedObject var model: LauncherViewModel
	@Binding var confirmsGameUninstall: Bool

	var body: some View {
		SettingsPage(title: "Installation", subtitle: "Game files and diagnostics") {
			SettingsPanel(title: "Arknights", systemImage: "shippingbox") {
				LabeledContent("Status") {
					Text(gameStatus)
						.foregroundStyle(model.isDownloading ? SettingsVisuals.cyan : .secondary)
				}
				Divider()
				LabeledContent("Location") {
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
				Divider()
				HStack {
					Menu("Installation Location", systemImage: "externaldrive") {
						Button("Choose New Location…", action: model.chooseInstallDirectory)
						Button(
							"Locate Existing Installation…",
							action: model.locateExistingInstallation
						)
					}
					.disabled(model.isDownloading)
					Spacer()
				}
				Divider()
				SettingsActionRow(
					title: "Repair",
					detail: "Check every game file and download missing or damaged files again."
				) {
					Button(
						"Repair…", systemImage: "wrench.and.screwdriver", action: model.repairGame
					)
					.disabled(!model.isInstalled || !model.canInstall)
				}
			}

			SettingsPanel(title: "Remove", systemImage: "trash") {
				SettingsActionRow(
					title: "Game files",
					detail: "Move the selected game installation to the Trash."
				) {
					Button("Uninstall Game…", role: .destructive) {
						confirmsGameUninstall = true
					}
					.disabled(!model.isInstalled || model.isDownloading)
				}
				Divider()
				SettingsActionRow(
					title: "Launcher",
					detail: "Reveal the launcher in Finder."
				) {
					Button("Show in Finder", action: model.revealApplication)
				}
			}

			SettingsPanel(title: "Diagnostics", systemImage: "waveform.path.ecg") {
				SettingsActionRow(
					title: "Launcher and Wine logs",
					detail: "Use these files when reporting startup or game problems."
				) {
					Button("Show Logs", systemImage: "folder", action: model.revealLogs)
				}
			}
		}
	}

	private var gameStatus: String {
		if model.isDownloading, let progress = model.progress {
			return "Downloading \(Int(progress.fraction * 100))%"
		}
		if model.isDownloading { return "Preparing download" }
		if model.isInstalled { return "Installed" }
		return model.hasPartialDownload ? "Paused" : "Not installed"
	}
}

struct AboutSettingsPage: View {
	@ObservedObject var model: LauncherViewModel
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
					Link("LuMiSxh", destination: URL(string: "https://github.com/LuMiSxh")!)
						.font(.callout.weight(.medium))
						.foregroundStyle(SettingsVisuals.cyan)
				}
				Spacer()
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
				Divider()
				DocumentLinkRow(title: "MPL-2.0 License", systemImage: "checkmark.seal") {
					presentedDocument = .projectLicense
				}
				Divider()
				DocumentLinkRow(title: "Third-Party Notices", systemImage: "shippingbox") {
					presentedDocument = .thirdPartyNotices
				}
			}

			SettingsPanel(title: "Arknights", systemImage: "link") {
				HStack(spacing: 18) {
					if let agreement = model.branding?.userAgreement {
						Link("User Agreement", destination: agreement)
							.foregroundStyle(SettingsVisuals.cyan)
					}
					if let privacy = model.branding?.privacyPolicy {
						Link("Privacy Policy", destination: privacy)
							.foregroundStyle(SettingsVisuals.cyan)
					}
					Spacer()
					Text("This launcher is not affiliated with Hypergryph or Yostar.")
						.font(.caption)
						.foregroundStyle(.secondary)
				}
			}
		}
	}

	private var appVersion: String {
		Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
			?? "Development"
	}
}
