// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct ContentView: View {
	@ObservedObject var model: LauncherViewModel
	@State private var settingsPresented = false

	private let cyan = Color(red: 0.094, green: 0.82, blue: 1)

	var body: some View {
		ZStack {
			artwork

			VStack(spacing: 0) {
				HStack {
					Text("ARKNIGHTS")
						.font(.custom("Avenir Next Condensed", size: 20).weight(.bold))
						.tracking(1.8)
						.padding(.horizontal, 14)
						.padding(.vertical, 8)
						.glassEffect(.regular, in: .capsule)
					Spacer()
				}
				.padding(20)

				Spacer()
				controlBar
					.padding(20)
			}
		}
		.background(Color.black)
		.preferredColorScheme(.dark)
		.toolbarBackground(.hidden, for: .windowToolbar)
		.toolbar {
			ToolbarItem(placement: .primaryAction) {
				Button {
					settingsPresented = true
				} label: {
					Label("Settings", systemImage: "gearshape")
				}
				.buttonStyle(.glass)
				.help("Open launcher settings")
			}
		}
		.sheet(isPresented: $settingsPresented) {
			LauncherSettingsView(model: model)
		}
	}

	private var artwork: some View {
		GeometryReader { proxy in
			Group {
				if let image = model.heroArtwork {
					Image(nsImage: image)
						.resizable()
						.scaledToFill()
						.accessibilityLabel("Arknights artwork")
				} else {
					fallbackArtwork
				}
			}
			.frame(width: proxy.size.width, height: proxy.size.height)
			.clipped()
		}
	}

	private var fallbackArtwork: some View {
		ZStack {
			Color(red: 0.035, green: 0.04, blue: 0.045)
			Text("A")
				.font(.custom("Avenir Next Condensed", size: 440).weight(.black))
				.foregroundStyle(.white.opacity(0.07))
			Rectangle()
				.fill(cyan.opacity(0.4))
				.frame(width: 620, height: 10)
				.rotationEffect(.degrees(-42))
		}
	}

	private var controlBar: some View {
		VStack(spacing: 10) {
			if model.phase == .downloading {
				ProgressView(value: model.progress?.fraction ?? 0)
					.progressViewStyle(.linear)
					.tint(cyan)
			}

			HStack(spacing: 14) {
				VStack(alignment: .leading, spacing: 2) {
					Text(statusTitle)
						.font(.system(size: 14, weight: .semibold))
					if let detail = statusDetail {
						Text(detail)
							.font(.caption)
							.foregroundStyle(.secondary)
							.lineLimit(1)
					}
				}

				Spacer(minLength: 16)

				if model.versionText != "—" {
					Text(model.versionText)
						.font(.system(size: 11, weight: .medium, design: .monospaced))
						.foregroundStyle(.secondary)
				}

				if model.launcherUpdate != nil {
					Button(
						"Launcher Update", systemImage: "arrow.down.app",
						action: model.openLauncherUpdate
					)
					.buttonStyle(.glass)
					.help("Open the latest launcher release in your browser")
				}

				primaryAction
			}
		}
		.padding(16)
		.glassEffect(
			.regular.tint(Color.black.opacity(0.52)),
			in: .rect(cornerRadius: 18)
		)
	}

	@ViewBuilder
	private var primaryAction: some View {
		if model.phase == .downloading {
			Button("Pause", systemImage: "pause.fill", action: model.cancelDownload)
				.buttonStyle(.glass)
				.help("Pause the download; it resumes from partial files later")
		} else if !model.isInstalled {
			Button("Install", systemImage: "arrow.down", action: model.installOrUpdate)
				.buttonStyle(.glassProminent)
				.tint(cyan)
				.disabled(!model.canInstall)
				.keyboardShortcut(.defaultAction)
				.help("Download and verify the official Global PC files")
		} else if model.isGameUpdateAvailable {
			Button("Update", systemImage: "arrow.down", action: model.installOrUpdate)
				.buttonStyle(.glassProminent)
				.tint(cyan)
				.disabled(!model.canInstall)
				.keyboardShortcut(.defaultAction)
				.help("Download the changed game files")
		} else {
			Button("Play", systemImage: "play.fill", action: model.launch)
				.buttonStyle(.glassProminent)
				.tint(cyan)
				.disabled(!model.canLaunch)
				.keyboardShortcut(.defaultAction)
				.help("Start Arknights")
		}
	}

	private var statusTitle: String {
		if model.phase == .downloading, let progress = model.progress {
			return "\(Int(progress.fraction * 100))%"
		}
		if case .failed = model.phase { return "Needs attention" }
		return model.activityMessage
	}

	private var statusDetail: String? {
		if model.phase == .downloading, let progress = model.progress {
			let downloaded = ByteCountFormatter.string(
				fromByteCount: progress.downloadedBytes,
				countStyle: .file
			)
			let total = ByteCountFormatter.string(
				fromByteCount: progress.totalBytes, countStyle: .file)
			return "\(downloaded) of \(total)"
		}
		if case .failed(let message) = model.phase { return message }
		return nil
	}
}

private struct LauncherSettingsView: View {
	@ObservedObject var model: LauncherViewModel
	@Environment(\.dismiss) private var dismiss
	@State private var selectedSection = SettingsSection.general
	@State private var confirmsGameUninstall = false

	var body: some View {
		NavigationSplitView {
			List(SettingsSection.allCases, selection: $selectedSection) { section in
				Label(section.title, systemImage: section.systemImage)
					.tag(section)
			}
			.navigationSplitViewColumnWidth(170)
		} detail: {
			Group {
				switch selectedSection {
				case .general: generalSettings
				case .installation: installationSettings
				case .about: aboutSettings
				}
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
			.padding(26)
		}
		.frame(width: 740, height: 500)
		.toolbar {
			ToolbarItem(placement: .confirmationAction) {
				Button("Done") { dismiss() }
			}
		}
		.confirmationDialog(
			"Uninstall Arknights?",
			isPresented: $confirmsGameUninstall,
			titleVisibility: .visible
		) {
			Button("Move Game to Trash", role: .destructive, action: model.uninstallGame)
			Button("Cancel", role: .cancel) {}
		} message: {
			Text("The launcher stays installed.")
		}
	}

	private var generalSettings: some View {
		Form {
			Section("Display") {
				Picker("Window Mode", selection: $model.launchOptions.displayMode) {
					ForEach(GameDisplayMode.allCases, id: \.self) { mode in
						Text(mode.displayName).tag(mode)
					}
				}
				.help("Applied the next time the game starts")

				Picker("Resolution", selection: $model.launchOptions.resolution) {
					ForEach(GameResolution.allCases, id: \.self) { resolution in
						Text(resolution.displayName).tag(resolution)
					}
				}
				.help("Applied the next time the game starts")
			}

			Section("Updates") {
				Toggle(
					"Check for launcher updates", isOn: $model.automaticallyChecksLauncherUpdates
				)
				.help("Checks GitHub when the launcher opens; installation remains manual")
				LabeledContent("Launcher") {
					HStack {
						Text(model.launcherUpdateStatus ?? "Not checked")
							.foregroundStyle(.secondary)
						Button("Check Now", action: model.checkLauncherUpdates)
							.disabled(model.isCheckingLauncherUpdates)
					}
				}

				Toggle("Check for game updates", isOn: $model.automaticallyChecksGameUpdates)
					.help("Checks Yostar for a newer Global PC version when the launcher opens")
				LabeledContent("Game") {
					HStack {
						Text(model.isGameUpdateAvailable ? "Update available" : model.versionText)
							.foregroundStyle(.secondary)
						Button("Check Now", action: model.checkGameUpdates)
							.disabled(model.phase == .downloading)
					}
				}
			}

			Section("Artwork") {
				HStack {
					Button("Choose Image…", action: model.chooseCustomArtwork)
						.help("Copy a local image into the launcher data folder")
					Button("Use Default", action: model.resetArtwork)
						.help("Use artwork supplied by the official launcher service")
				}
			}
		}
		.formStyle(.grouped)
		.navigationTitle("General")
	}

	private var installationSettings: some View {
		Form {
			Section("Game") {
				LabeledContent("Status", value: model.isInstalled ? "Installed" : "Not installed")
				LabeledContent("Location") {
					Text(model.installDirectory.path)
						.lineLimit(2)
						.truncationMode(.middle)
						.textSelection(.enabled)
				}

				HStack {
					Button("Choose Location…", action: model.chooseInstallDirectory)
						.help("Choose the parent folder for a new installation")
					Button("Locate Existing…", action: model.locateExistingInstallation)
						.help("Use an existing folder containing Arknights.exe")
					Button("Show in Finder", action: model.revealInstallDirectory)
						.disabled(!model.isInstalled)
				}

				HStack {
					Button("Repair", action: model.repairGame)
						.disabled(!model.isInstalled || !model.canInstall)
						.help("Verify every game file and redownload damaged files")
					Button("Uninstall Game…", role: .destructive) {
						confirmsGameUninstall = true
					}
					.disabled(!model.isInstalled)
				}
			}

			Section("Launcher") {
				Button("Show App in Finder", action: model.revealApplication)
					.help("Move the app to the Trash to uninstall the launcher")
			}
		}
		.formStyle(.grouped)
		.navigationTitle("Installation")
	}

	private var aboutSettings: some View {
		Form {
			Section {
				HStack(alignment: .top, spacing: 16) {
					Image(nsImage: NSApplication.shared.applicationIconImage)
						.resizable()
						.frame(width: 68, height: 68)
					VStack(alignment: .leading, spacing: 4) {
						Text("Arknights Client").font(.title2.bold())
						Text("Version \(appVersion)").foregroundStyle(.secondary)
						Text("Unofficial macOS launcher by LuMiSxh.")
							.foregroundStyle(.secondary)
					}
				}
			}

			Section("Legal") {
				Button("Changelog", action: model.openChangelog)
				Button("Source Code", action: model.openSourceCode)
				Button("MPL-2.0 License", action: model.openProjectLicense)
				Button("Third-Party Notices", action: model.openThirdPartyNotices)
				if let agreement = model.branding?.userAgreement {
					Link("Arknights User Agreement", destination: agreement)
				}
				if let privacy = model.branding?.privacyPolicy {
					Link("Arknights Privacy Policy", destination: privacy)
				}
				Text("Not affiliated with Hypergryph or Yostar.")
					.font(.caption)
					.foregroundStyle(.secondary)
			}
		}
		.formStyle(.grouped)
		.navigationTitle("About")
	}

	private var appVersion: String {
		Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
			?? "Development"
	}
}

private enum SettingsSection: String, CaseIterable, Identifiable {
	case general
	case installation
	case about

	var id: String { rawValue }

	var title: String {
		switch self {
		case .general: "General"
		case .installation: "Installation"
		case .about: "About"
		}
	}

	var systemImage: String {
		switch self {
		case .general: "slider.horizontal.3"
		case .installation: "externaldrive"
		case .about: "info.circle"
		}
	}
}
