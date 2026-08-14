import AppKit
import Combine
import Foundation

@MainActor
final class LauncherViewModel: ObservableObject {
  @Published private(set) var phase: LauncherPhase = .checking
  @Published private(set) var configuration: GameConfiguration?
  @Published private(set) var progress: DownloadProgress?
  @Published private(set) var runtimeName: String?
  @Published private(set) var isInstalled = false
  @Published private(set) var activityMessage = "Contacting Yostar…"
  @Published var installDirectory: URL

  private let api: LauncherAPI
  private let installer: GameInstaller
  private var activeTask: Task<Void, Never>?

  init(
    api: LauncherAPI = LauncherAPI(),
    arguments: [String] = ProcessInfo.processInfo.arguments
  ) {
    self.api = api
    installer = GameInstaller(api: api)

    let baseDirectory =
      FileManager.default.urls(
        for: .applicationSupportDirectory,
        in: .userDomainMask
      ).first ?? FileManager.default.temporaryDirectory
    installDirectory =
      baseDirectory
      .appending(path: "Arknights Client", directoryHint: .isDirectory)
      .appending(path: "Arknights_EN", directoryHint: .isDirectory)

    refreshRuntime()
    let installOnLaunch =
      arguments.contains("--install")
      || arguments.contains("--install-and-launch")
    let launchAfterInstall = arguments.contains("--install-and-launch")
    activeTask = Task { [weak self] in
      await self?.refresh()
      if installOnLaunch {
        self?.startInstallation(launchAfterCompletion: launchAfterInstall)
      }
    }
  }

  deinit {
    activeTask?.cancel()
  }

  var versionText: String {
    configuration?.gameLatestVersion ?? "—"
  }

  var installSizeText: String {
    configuration?.decompressionSize ?? "—"
  }

  var canInstall: Bool {
    configuration != nil && phase != .downloading
  }

  var canLaunch: Bool {
    isInstalled && runtimeName != nil && phase != .downloading && phase != .launching
  }

  func refresh() async {
    phase = .checking
    activityMessage = "Checking the current PC release…"
    do {
      configuration = try await api.gameConfiguration()
      updateInstalledState()
      phase = .ready
      activityMessage =
        isInstalled
        ? "The game files are present. You can update or launch."
        : "Ready to download the official PC game files."
    } catch is CancellationError {
      activityMessage = "Cancelled."
    } catch {
      show(error)
    }
  }

  func chooseInstallDirectory() {
    let panel = NSOpenPanel()
    panel.title = "Choose the Arknights installation folder"
    panel.prompt = "Choose"
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.canCreateDirectories = true
    panel.allowsMultipleSelection = false
    panel.directoryURL = installDirectory.deletingLastPathComponent()
    if panel.runModal() == .OK, let selected = panel.url {
      installDirectory =
        selected.lastPathComponent == "Arknights_EN"
        ? selected
        : selected.appending(path: "Arknights_EN", directoryHint: .isDirectory)
      updateInstalledState()
    }
  }

  func installOrUpdate() {
    startInstallation(launchAfterCompletion: false)
  }

  private func startInstallation(launchAfterCompletion: Bool) {
    guard let configuration else {
      show(LauncherError.missingConfiguration)
      return
    }
    activeTask?.cancel()
    progress = nil
    phase = .downloading
    activityMessage = "Preparing the official file manifest…"

    activeTask = Task { [weak self] in
      guard let self else { return }
      do {
        let result = try await installer.install(
          configuration: configuration,
          into: installDirectory
        ) { [weak self] update in
          await MainActor.run {
            self?.progress = update
            self?.activityMessage = "Downloading \(update.currentFile)…"
          }
        }
        isInstalled = true
        phase = .ready
        activityMessage =
          result.downloadedFiles == 0
          ? "All game files already match the latest release."
          : "Downloaded and verified \(result.downloadedFiles) files."
        if launchAfterCompletion {
          launch()
        }
      } catch is CancellationError {
        phase = .ready
        activityMessage = "Download paused. Partial files will resume next time."
      } catch {
        show(error)
      }
    }
  }

  func cancelDownload() {
    activeTask?.cancel()
  }

  func launch() {
    guard let configuration else {
      show(LauncherError.missingConfiguration)
      return
    }
    let executable = installDirectory.appending(path: configuration.executableName)
    guard FileManager.default.fileExists(atPath: executable.path) else {
      show(LauncherError.gameNotInstalled(executable))
      return
    }
    guard let runtime = WineRuntime.discover() else {
      refreshRuntime()
      show(LauncherError.wineRuntimeMissing)
      return
    }

    phase = .launching
    activityMessage = "Starting Arknights with \(runtime.displayName)…"
    activeTask = Task { [weak self] in
      guard let self else { return }
      do {
        let prefix =
          installDirectory
          .deletingLastPathComponent()
          .appending(path: "WinePrefix", directoryHint: .isDirectory)
        let processIdentifier = try await runtime.launch(
          gameExecutable: executable,
          prefixDirectory: prefix
        )
        phase = .running(processIdentifier: processIdentifier)
        activityMessage = "Arknights started as process \(processIdentifier)."
      } catch {
        show(error)
      }
    }
  }

  func refreshRuntime() {
    runtimeName = WineRuntime.discover()?.displayName
  }

  func revealInstallDirectory() {
    NSWorkspace.shared.activateFileViewerSelecting([installDirectory])
  }

  private func updateInstalledState() {
    guard let executableName = configuration?.executableName else {
      isInstalled = false
      return
    }
    isInstalled = FileManager.default.fileExists(
      atPath: installDirectory.appending(path: executableName).path
    )
  }

  private func show(_ error: Error) {
    let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    phase = .failed(message)
    activityMessage = message
  }
}
