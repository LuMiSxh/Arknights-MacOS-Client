import SwiftUI

struct ContentView: View {
  @ObservedObject var model: LauncherViewModel

  private let cyan = Color(red: 0.29, green: 0.85, blue: 0.91)
  private let orange = Color(red: 0.96, green: 0.48, blue: 0.20)
  private let panel = Color(red: 0.075, green: 0.09, blue: 0.11)
  private let line = Color.white.opacity(0.13)

  var body: some View {
    ZStack {
      Color(red: 0.035, green: 0.045, blue: 0.055)
        .ignoresSafeArea()

      LinearGradient(
        colors: [cyan.opacity(0.10), .clear, orange.opacity(0.06)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      .ignoresSafeArea()

      HStack(spacing: 0) {
        identityPanel
          .frame(width: 264)

        Rectangle()
          .fill(line)
          .frame(width: 1)

        mainPanel
          .padding(32)
      }
    }
    .frame(minWidth: 880, minHeight: 560)
    .preferredColorScheme(.dark)
  }

  private var identityPanel: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 8) {
        Rectangle()
          .fill(cyan)
          .frame(width: 28, height: 3)
        Text("RHODES ISLAND")
          .font(.system(size: 10, weight: .bold, design: .monospaced))
          .tracking(1.6)
          .foregroundStyle(cyan)
      }

      Spacer().frame(height: 38)

      Text("ARKNIGHTS")
        .font(.system(size: 28, weight: .heavy, design: .rounded))
        .tracking(1.4)
        .foregroundStyle(.white)
      Text("// macOS CLIENT")
        .font(.system(size: 13, weight: .semibold, design: .monospaced))
        .tracking(1.2)
        .foregroundStyle(.white.opacity(0.58))

      Spacer()

      VStack(alignment: .leading, spacing: 15) {
        statusRow(label: "NETWORK", value: networkStatus, tint: statusColor)
        statusRow(
          label: "RUNTIME", value: model.runtimeName ?? "Not detected",
          tint: model.runtimeName == nil ? orange : cyan)
        statusRow(
          label: "GAME FILES", value: model.isInstalled ? "Installed" : "Not installed",
          tint: model.isInstalled ? cyan : .white.opacity(0.46))
      }
      .padding(16)
      .background(panel.opacity(0.72), in: RoundedRectangle(cornerRadius: 10))
      .overlay {
        RoundedRectangle(cornerRadius: 10)
          .stroke(line, lineWidth: 1)
      }

      Spacer().frame(height: 18)
      Text("OFFICIAL PC DISTRIBUTION")
        .font(.system(size: 9, weight: .bold, design: .monospaced))
        .tracking(1.1)
        .foregroundStyle(.white.opacity(0.34))
    }
    .padding(28)
    .background(panel.opacity(0.55))
  }

  private var mainPanel: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 8) {
          Text("ARKNIGHTS // macOS Client")
            .font(.system(size: 22, weight: .bold, design: .rounded))
          Text(model.phase.title.uppercased())
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .tracking(1.3)
            .foregroundStyle(statusColor)
        }

        Spacer()

        Button(action: model.refreshRuntime) {
          Label("Refresh Runtime", systemImage: "arrow.clockwise")
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white.opacity(0.68))
      }

      Rectangle().fill(line).frame(height: 1).padding(.vertical, 24)

      HStack(spacing: 12) {
        metric(label: "LATEST PC VERSION", value: model.versionText)
        metric(label: "DISK REQUIREMENT", value: model.installSizeText)
        metric(label: "INSTALL STATUS", value: model.isInstalled ? "READY" : "REQUIRED")
      }

      Spacer().frame(height: 22)

      Text("INSTALL LOCATION")
        .font(.system(size: 10, weight: .bold, design: .monospaced))
        .tracking(1.2)
        .foregroundStyle(.white.opacity(0.44))

      HStack(spacing: 12) {
        Text(model.installDirectory.path)
          .font(.system(size: 12, design: .monospaced))
          .foregroundStyle(.white.opacity(0.78))
          .lineLimit(1)
          .truncationMode(.middle)
        Spacer(minLength: 0)
        Button("Change", action: model.chooseInstallDirectory)
          .buttonStyle(SecondaryButtonStyle())
          .disabled(model.phase == .downloading)
      }
      .padding(14)
      .background(panel, in: RoundedRectangle(cornerRadius: 8))
      .overlay { RoundedRectangle(cornerRadius: 8).stroke(line, lineWidth: 1) }

      Spacer().frame(height: 22)
      progressPanel

      Spacer(minLength: 24)

      Text(model.activityMessage)
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.white.opacity(0.72))
        .lineLimit(2)
        .frame(maxWidth: .infinity, alignment: .leading)

      Spacer().frame(height: 18)
      controls
    }
  }

  private var progressPanel: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text(model.phase == .downloading ? "TRANSFER PROGRESS" : "DOWNLOAD STATUS")
          .font(.system(size: 10, weight: .bold, design: .monospaced))
          .tracking(1.2)
          .foregroundStyle(.white.opacity(0.44))
        Spacer()
        Text(progressSummary)
          .font(.system(size: 11, weight: .medium, design: .monospaced))
          .foregroundStyle(cyan)
      }

      ProgressView(value: model.progress?.fraction ?? (model.isInstalled ? 1 : 0))
        .tint(cyan)
        .scaleEffect(x: 1, y: 1.8, anchor: .center)
        .padding(.vertical, 3)

      Text(model.progress?.currentFile ?? "Awaiting installation command")
        .font(.system(size: 11, design: .monospaced))
        .foregroundStyle(.white.opacity(0.46))
        .lineLimit(1)
        .truncationMode(.middle)
    }
    .padding(16)
    .background(panel.opacity(0.75), in: RoundedRectangle(cornerRadius: 10))
    .overlay { RoundedRectangle(cornerRadius: 10).stroke(line, lineWidth: 1) }
  }

  private var controls: some View {
    HStack(spacing: 10) {
      Button(action: model.launch) {
        Label("Launch", systemImage: "play.fill")
          .frame(minWidth: 118)
      }
      .buttonStyle(PrimaryButtonStyle(tint: cyan))
      .disabled(!model.canLaunch)

      if model.phase == .downloading {
        Button("Cancel Download", action: model.cancelDownload)
          .buttonStyle(PrimaryButtonStyle(tint: orange))
      } else {
        Button(model.isInstalled ? "Update Game" : "Install Game", action: model.installOrUpdate)
          .buttonStyle(SecondaryButtonStyle())
          .disabled(!model.canInstall)
      }

      Spacer()

      Button(action: model.revealInstallDirectory) {
        Label("Reveal Folder", systemImage: "folder")
      }
      .buttonStyle(SecondaryButtonStyle())
    }
  }

  private var networkStatus: String {
    switch model.phase {
    case .failed: "Attention required"
    case .checking: "Contacting servers"
    default: "Online"
    }
  }

  private var statusColor: Color {
    switch model.phase {
    case .failed: orange
    case .checking, .launching: .white.opacity(0.66)
    default: cyan
    }
  }

  private var progressSummary: String {
    guard let progress = model.progress else {
      return model.isInstalled ? "100%" : "0%"
    }
    return
      "\(Int(progress.fraction * 100))%  ·  \(byteText(progress.downloadedBytes)) / \(byteText(progress.totalBytes))  ·  \(progress.completedFiles)/\(progress.totalFiles) files"
  }

  private func byteText(_ count: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: count, countStyle: .file)
  }

  private func statusRow(label: String, value: String, tint: Color) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(label)
        .font(.system(size: 9, weight: .bold, design: .monospaced))
        .tracking(1.1)
        .foregroundStyle(.white.opacity(0.38))
      Text(value)
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(tint)
        .lineLimit(1)
    }
  }

  private func metric(label: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 7) {
      Text(label)
        .font(.system(size: 9, weight: .bold, design: .monospaced))
        .tracking(1.1)
        .foregroundStyle(.white.opacity(0.40))
      Text(value)
        .font(.system(size: 16, weight: .semibold, design: .monospaced))
        .foregroundStyle(.white.opacity(0.88))
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
    .padding(14)
    .background(panel.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
    .overlay { RoundedRectangle(cornerRadius: 8).stroke(line, lineWidth: 1) }
  }
}

private struct PrimaryButtonStyle: ButtonStyle {
  let tint: Color
  @Environment(\.isEnabled) private var isEnabled

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 13, weight: .bold))
      .foregroundStyle(Color.black.opacity(configuration.isPressed ? 0.72 : 0.88))
      .padding(.horizontal, 18)
      .frame(height: 38)
      .background(
        tint.opacity(configuration.isPressed ? 0.72 : 1), in: RoundedRectangle(cornerRadius: 7)
      )
      .opacity(isEnabled ? 1 : 0.36)
  }
}

private struct SecondaryButtonStyle: ButtonStyle {
  @Environment(\.isEnabled) private var isEnabled

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 13, weight: .semibold))
      .foregroundStyle(.white.opacity(isEnabled ? (configuration.isPressed ? 0.52 : 0.82) : 0.30))
      .padding(.horizontal, 14)
      .frame(height: 38)
      .background(
        .white.opacity(configuration.isPressed ? 0.05 : 0.09), in: RoundedRectangle(cornerRadius: 7)
      )
      .overlay {
        RoundedRectangle(cornerRadius: 7)
          .stroke(.white.opacity(isEnabled ? 0.15 : 0.07), lineWidth: 1)
      }
  }
}
