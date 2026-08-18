// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct ContentView: View {
	var model: LauncherViewModel
	@State private var settingsPresented = false

	private let cyan = SettingsVisuals.cyan

	var body: some View {
		ZStack {
			artwork
				.ignoresSafeArea(.container, edges: .top)

			VStack(spacing: 0) {
				topBar
				Spacer()
				controlBar
					.padding(20)
			}
		}
		.background(Color.black)
		.preferredColorScheme(.dark)
		.sheet(isPresented: $settingsPresented) {
			LauncherSettingsView(model: model)
		}
		.sheet(item: popupBinding) { popup in
			LauncherPopupView(
				popup: popup,
				dismiss: model.dismissPopup,
				openAction: model.openPopupAction
			)
		}
	}

	private var popupBinding: Binding<LauncherPopup?> {
		Binding(
			get: { model.popup },
			set: { popup in
				if popup == nil { model.dismissPopup() }
			}
		)
	}

	private var topBar: some View {
		HStack(alignment: .top) {
			ArknightsWordmark(logo: model.officialLogo, cyan: cyan)
				.padding(.top, 34)
			Spacer()
			Button {
				settingsPresented = true
			} label: {
				Image(systemName: "gearshape")
					.font(.system(size: 17, weight: .medium))
					.frame(width: 20, height: 20)
			}
			.buttonStyle(.glass)
			.buttonBorderShape(.circle)
			.controlSize(.large)
			.keyboardShortcut(",", modifiers: .command)
			.help("Open launcher settings")
		}
		.padding(.top, 8)
		.padding(.horizontal, 14)
		.ignoresSafeArea(.container, edges: .top)
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
		HStack(spacing: 16) {
			controlBarLeadingRegion
				.frame(maxWidth: .infinity, alignment: .leading)

			HStack(spacing: 8) {
				if model.launcherUpdate != nil {
					Button(
						"Launcher Update", systemImage: "arrow.down.app",
						action: model.openLauncherUpdate
					)
					.buttonStyle(.glass)
					.buttonBorderShape(.capsule)
					.help("Open the latest launcher release in your browser")
				}

				primaryAction
			}
		}
		.padding(16)
		.glassEffect(
			.regular.tint(Color.black.opacity(0.52)),
			in: Capsule()
		)
	}

	@ViewBuilder
	private var controlBarLeadingRegion: some View {
		if model.isDownloading {
			VStack(alignment: .leading, spacing: 7) {
				HStack(alignment: .firstTextBaseline, spacing: 16) {
					HStack(alignment: .firstTextBaseline, spacing: 10) {
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
					versionLabel
				}

				ProgressView(value: model.progress?.fraction ?? 0)
					.progressViewStyle(.linear)
					.tint(cyan)
			}
		} else {
			HStack(alignment: .firstTextBaseline, spacing: 16) {
				VStack(alignment: .leading, spacing: 2) {
					Text(statusTitle)
						.font(.system(size: 14, weight: .semibold))
					if let detail = statusDetail {
						Text(detail)
							.font(.caption)
							.foregroundStyle(.secondary)
							.lineLimit(1)
						if isFailed {
							CyanActionLink(title: "Report Problem") {
								NSWorkspace.shared.open(IssueReportURL.build(problem: detail))
							}
							.font(.caption)
						}
					}
				}

				Spacer(minLength: 16)
				versionLabel
			}
		}
	}

	@ViewBuilder
	private var versionLabel: some View {
		HStack(spacing: 6) {
			if let countdown = model.resetCountdownText {
				Text(countdown)
					.font(.system(size: 11, weight: .medium, design: .monospaced))
					.foregroundStyle(.secondary)
			}
			regionIndicator
			if model.showsGameVersion, model.versionText != "—" {
				Text(model.versionText)
					.font(.system(size: 11, weight: .medium, design: .monospaced))
					.foregroundStyle(.secondary)
			}
		}
	}

	/// Stays invisible for the common single-region case; only becomes an interactive
	/// switcher once a second region is actually installed, so the landing page doesn't
	/// carry region chrome nobody can use yet.
	@ViewBuilder
	private var regionIndicator: some View {
		if model.installedRegions.count > 1 {
			Menu {
				ForEach(model.installedRegions) { region in
					Button {
						model.selectRegion(region)
					} label: {
						if region == model.region {
							Label(region.displayName, systemImage: "checkmark")
						} else {
							Text(region.displayName)
						}
					}
				}
			} label: {
				HStack(spacing: 3) {
					Text(model.region.displayName)
					Image(systemName: "chevron.up.chevron.down")
						.font(.system(size: 7, weight: .bold))
						.accessibilityHidden(true)
				}
				.font(.system(size: 10, weight: .semibold))
				.foregroundStyle(cyan)
				.padding(.horizontal, 6)
				.padding(.vertical, 2)
				.background(cyan.opacity(0.15), in: Capsule())
			}
			.menuStyle(.button)
			.buttonStyle(.plain)
			.disabled(!model.canSwitchRegion)
			.help("Switch between installed regions")
		} else if model.region != .global {
			Text(model.region.displayName)
				.font(.system(size: 10, weight: .semibold))
				.foregroundStyle(cyan)
				.padding(.horizontal, 6)
				.padding(.vertical, 2)
				.background(cyan.opacity(0.15), in: Capsule())
		}
	}

	@ViewBuilder
	private var primaryAction: some View {
		if model.isGameRunning {
			Button("Stop", systemImage: "stop.fill", action: model.stopGame)
				.buttonStyle(.glass)
				.buttonBorderShape(.capsule)
				.controlSize(.large)
				.disabled(!model.canStopGame)
				.help("Stop Arknights and its Windows runtime")
		} else if model.isDownloading {
			Button("Pause", systemImage: "pause.fill", action: model.cancelDownload)
				.buttonStyle(.glass)
				.buttonBorderShape(.capsule)
				.controlSize(.large)
				.help("Pause the download; it resumes from partial files later")
		} else if !model.isInstalled {
			Button(
				model.hasPartialDownload ? "Resume" : "Install",
				systemImage: model.hasPartialDownload ? "arrow.clockwise" : "arrow.down",
				action: model.installOrUpdate
			)
			.buttonStyle(.glassProminent)
			.buttonBorderShape(.capsule)
			.controlSize(.large)
			.tint(cyan)
			.disabled(!model.canInstall)
			.keyboardShortcut(.defaultAction)
			.help(
				model.hasPartialDownload
					? "Continue downloading from the partial files"
					: "Download and verify the official Global PC files"
			)
		} else if model.isGameUpdateAvailable {
			Button("Update", systemImage: "arrow.down", action: model.installOrUpdate)
				.buttonStyle(.glassProminent)
				.buttonBorderShape(.capsule)
				.controlSize(.large)
				.tint(cyan)
				.disabled(!model.canInstall)
				.keyboardShortcut(.defaultAction)
				.help("Download the changed game files")
		} else {
			Button("Play", systemImage: "play.fill", action: model.launch)
				.buttonStyle(.glassProminent)
				.buttonBorderShape(.capsule)
				.controlSize(.large)
				.tint(cyan)
				.disabled(!model.canLaunch)
				.keyboardShortcut(.defaultAction)
				.help("Start Arknights")
		}
	}

	private var statusTitle: String {
		if model.activityMessage == "Pausing…" {
			return model.activityMessage
		}
		if model.isDownloading, let progress = model.progress {
			return "\(Int(progress.fraction * 100))%"
		}
		if case .failed = model.phase { return "Needs attention" }
		return model.activityMessage
	}

	private var statusDetail: String? {
		if model.isDownloading, let progress = model.progress {
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

	private var isFailed: Bool {
		if case .failed = model.phase { return true }
		return false
	}
}
