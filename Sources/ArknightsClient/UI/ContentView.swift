// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct ContentView: View {
	var model: LauncherViewModel
	@State private var settingsPresented = false

	private var cyan: Color { model.accentColor }

	var body: some View {
		ZStack {
			BackgroundMusicView(model: model)

			artwork
				.ignoresSafeArea(.container, edges: .top)

			// Seamless top-left corner vignette for traffic lights & wordmark readability
			LinearGradient(
				colors: [
					Color.black.opacity(0.62),
					Color.black.opacity(0.32),
					Color.clear,
				],
				startPoint: .topLeading,
				endPoint: .init(x: 0.38, y: 0.28)
			)
			.ignoresSafeArea(.container, edges: .top)
			.allowsHitTesting(false)

			VStack(spacing: 0) {
				topBar
				Spacer()
				VStack(spacing: 10) {
					hudPillRow
					controlBar
				}
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
				accentColor: cyan,
				accentTextColor: model.accentTextColor,
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
			.adaptiveGlassButton()
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
					.adaptiveGlassButton()
					.buttonBorderShape(.capsule)
					.help("Open the latest launcher release in your browser")
				}

				primaryAction
			}
		}
		.padding(16)
		.adaptiveGlassEffect(tint: model.hudTintColor, in: Capsule())
	}

	/// Only takes up the 10pt of VStack spacing above `controlBar` when at least one pill
	/// has content — mirrors the visibility checks inside `MusicHUDPill`/`VersionHUDPill`/
	/// `StatusHUDPill` so the common case (no music, single region) doesn't leave a stray gap.
	@ViewBuilder
	private var hudPillRow: some View {
		if hasMusicPill || hasVersionPill || hasStatusPill {
			HStack {
				Spacer(minLength: 16)
				HStack(spacing: 8) {
					MusicHUDPill(model: model)
					VersionHUDPill(model: model)
					StatusHUDPill(model: model)
				}
			}
		}
	}

	private var hasMusicPill: Bool {
		model.showsPlayingMusic && model.currentMusicTitle != nil
	}

	private var hasVersionPill: Bool {
		model.showsGameVersion && model.versionText != "—"
	}

	private var hasStatusPill: Bool {
		model.resetCountdownText != nil
			|| model.installedRegions.count > 1
			|| model.region != .global
	}

	@ViewBuilder
	private var controlBarLeadingRegion: some View {
		if model.isDownloading {
			VStack(alignment: .leading, spacing: 7) {
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

				ProgressView(value: model.progress?.fraction ?? 0)
					.progressViewStyle(.linear)
					.tint(cyan)
			}
		} else {
			VStack(alignment: .leading, spacing: 2) {
				Text(statusTitle)
					.font(.system(size: 14, weight: .semibold))
				if let detail = statusDetail {
					Text(detail)
						.font(.caption)
						.foregroundStyle(.secondary)
						.lineLimit(1)
					if isFailed {
						AccentActionLink(title: "Report Problem", accentColor: cyan) {
							NSWorkspace.shared.open(IssueReportURL.build(problem: detail))
						}
						.font(.caption)
					}
				}
			}
		}
	}

	@ViewBuilder
	private var primaryAction: some View {
		if model.isGameRunning {
			Button("Stop", systemImage: "stop.fill", action: model.stopGame)
				.adaptiveGlassButton()
				.buttonBorderShape(.capsule)
				.controlSize(.large)
				.disabled(!model.canStopGame)
				.help("Stop Arknights and its Windows runtime")
		} else if model.isDownloading {
			Button("Pause", systemImage: "pause.fill", action: model.cancelDownload)
				.adaptiveGlassButton()
				.buttonBorderShape(.capsule)
				.controlSize(.large)
				.help("Pause the download; it resumes from partial files later")
		} else if !model.isInstalled {
			Button(action: model.installOrUpdate) {
				Label(
					model.hasPartialDownload ? "Resume" : "Install",
					systemImage: model.hasPartialDownload ? "arrow.clockwise" : "arrow.down"
				)
				.foregroundStyle(model.accentTextColor)
			}
			.adaptiveGlassButton(prominent: true)
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
			Button(action: model.installOrUpdate) {
				Label("Update", systemImage: "arrow.down")
					.foregroundStyle(model.accentTextColor)
			}
			.adaptiveGlassButton(prominent: true)
			.buttonBorderShape(.capsule)
			.controlSize(.large)
			.tint(cyan)
			.disabled(!model.canInstall)
			.keyboardShortcut(.defaultAction)
			.help("Download the changed game files")
		} else {
			Button(action: model.launch) {
				Label("Play", systemImage: "play.fill")
					.foregroundStyle(model.accentTextColor)
			}
			.adaptiveGlassButton(prominent: true)
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
