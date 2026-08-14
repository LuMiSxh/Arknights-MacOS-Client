// SPDX-License-Identifier: MPL-2.0

import AppKit
import Combine
import Foundation

@MainActor
final class LauncherViewModel: ObservableObject {
	@Published private(set) var phase: LauncherPhase = .checking
	@Published private(set) var configuration: GameConfiguration?
	@Published private(set) var progress: DownloadProgress?
	@Published private(set) var runtimeName: String?
	@Published private(set) var branding: LauncherBranding?
	@Published private(set) var heroArtwork: NSImage?
	@Published private(set) var isInstalled = false
	@Published private(set) var installedVersion: String?
	@Published private(set) var isGameUpdateAvailable = false
	@Published private(set) var launcherUpdate: LauncherRelease?
	@Published private(set) var launcherUpdateStatus: String?
	@Published private(set) var isCheckingLauncherUpdates = false
	@Published private(set) var activityMessage = "Checking…"

	@Published var installDirectory: URL
	@Published var launchOptions: GameLaunchOptions {
		didSet { preferences.setLaunchOptions(launchOptions) }
	}
	@Published var automaticallyChecksLauncherUpdates: Bool {
		didSet {
			preferences.setAutomaticLauncherUpdates(automaticallyChecksLauncherUpdates)
			if automaticallyChecksLauncherUpdates { checkLauncherUpdates() }
		}
	}
	@Published var automaticallyChecksGameUpdates: Bool {
		didSet {
			preferences.setAutomaticGameUpdates(automaticallyChecksGameUpdates)
			if automaticallyChecksGameUpdates { checkGameUpdates() }
		}
	}

	private let api: LauncherAPI
	private let installer: GameInstaller
	private let artworkCache: ArtworkCache
	private let updateChecker: LauncherUpdateChecker
	private let paths: AppPaths
	private let preferences: LauncherPreferencesStore
	private var activeTask: Task<Void, Never>?
	private var launcherUpdateTask: Task<Void, Never>?

	init(
		api: LauncherAPI = LauncherAPI(),
		paths: AppPaths = AppPaths(),
		preferences: LauncherPreferencesStore = LauncherPreferencesStore(),
		updateChecker: LauncherUpdateChecker = LauncherUpdateChecker(),
		arguments: [String] = ProcessInfo.processInfo.arguments
	) {
		self.api = api
		self.paths = paths
		self.preferences = preferences
		self.updateChecker = updateChecker
		installer = GameInstaller(api: api)
		artworkCache = ArtworkCache(directory: paths.artworkCache)
		installDirectory = preferences.installDirectory(default: paths.globalGameInstall)
		launchOptions = preferences.launchOptions()
		automaticallyChecksLauncherUpdates = preferences.automaticLauncherUpdates()
		automaticallyChecksGameUpdates = preferences.automaticGameUpdates()

		refreshRuntime()
		let installOnLaunch =
			arguments.contains("--install") || arguments.contains("--install-and-launch")
		let launchAfterInstall = arguments.contains("--install-and-launch")
		let launchOnStart = arguments.contains("--launch")

		activeTask = Task { [weak self] in
			guard let self else { return }
			await refresh()
			if launchOnStart {
				launch()
			} else if installOnLaunch {
				startInstallation(launchAfterCompletion: launchAfterInstall)
			}
		}
		if automaticallyChecksLauncherUpdates {
			checkLauncherUpdates()
		}
	}

	deinit {
		activeTask?.cancel()
		launcherUpdateTask?.cancel()
	}

	var versionText: String {
		configuration?.gameLatestVersion ?? installedVersion ?? "—"
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

	func refresh(forceGameUpdateCheck: Bool = false) async {
		updateInstalledState()
		phase = .checking
		activityMessage = "Checking…"
		let hasCustomArtwork = loadCustomArtwork()

		async let brandingRequest = try? api.branding()
		if !isInstalled || automaticallyChecksGameUpdates || forceGameUpdateCheck {
			do {
				configuration = try await api.gameConfiguration()
				updateGameAvailability()
			} catch is CancellationError {
				activityMessage = "Paused"
			} catch {
				if !isInstalled {
					show(error)
					return
				}
			}
		}

		if let currentBranding = await brandingRequest {
			branding = currentBranding
			if !hasCustomArtwork,
				let data = try? await artworkCache.imageData(for: currentBranding)
			{
				heroArtwork = NSImage(data: data)
			}
		}

		phase = .ready
		activityMessage =
			isGameUpdateAvailable ? "Update available" : (isInstalled ? "Ready" : "Install")
	}

	func checkGameUpdates() {
		guard phase != .downloading else { return }
		activeTask?.cancel()
		activeTask = Task { [weak self] in
			await self?.refresh(forceGameUpdateCheck: true)
		}
	}

	func checkLauncherUpdates() {
		guard !isCheckingLauncherUpdates else { return }
		guard
			let endpointString = Bundle.main.object(forInfoDictionaryKey: "LauncherUpdatesURL")
				as? String,
			let endpoint = URL(string: endpointString)
		else {
			launcherUpdateStatus = "Update source unavailable"
			return
		}

		launcherUpdateTask?.cancel()
		isCheckingLauncherUpdates = true
		launcherUpdateStatus = "Checking…"
		launcherUpdateTask = Task { [weak self] in
			guard let self else { return }
			defer { isCheckingLauncherUpdates = false }
			do {
				let release = try await updateChecker.latestRelease(from: endpoint)
				let currentVersion =
					Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
					as? String ?? "0"
				if !release.isDraft && !release.isPrerelease
					&& updateChecker.isNewer(release.version, than: currentVersion)
				{
					launcherUpdate = release
					launcherUpdateStatus = "Version \(release.version) available"
				} else {
					launcherUpdate = nil
					launcherUpdateStatus = "Up to date"
				}
			} catch is CancellationError {
				launcherUpdateStatus = nil
			} catch {
				launcherUpdateStatus = "Couldn’t check for updates"
			}
		}
	}

	func openLauncherUpdate() {
		guard let url = launcherUpdate?.htmlURL else { return }
		NSWorkspace.shared.open(url)
	}

	func chooseInstallDirectory() {
		let panel = NSOpenPanel()
		panel.title = "Choose where to install Arknights"
		panel.prompt = "Choose"
		panel.canChooseDirectories = true
		panel.canChooseFiles = false
		panel.canCreateDirectories = true
		panel.allowsMultipleSelection = false
		panel.directoryURL = installDirectory.deletingLastPathComponent()
		if panel.runModal() == .OK, let selected = panel.url {
			installDirectory =
				selected.lastPathComponent == "Arknights_EN"
				? selected : selected.appending(path: "Arknights_EN", directoryHint: .isDirectory)
			preferences.setInstallDirectory(installDirectory)
			updateInstalledState()
		}
	}

	func locateExistingInstallation() {
		let panel = NSOpenPanel()
		panel.title = "Choose the folder containing Arknights.exe"
		panel.prompt = "Use Folder"
		panel.canChooseDirectories = true
		panel.canChooseFiles = false
		panel.allowsMultipleSelection = false
		panel.directoryURL = installDirectory
		if panel.runModal() == .OK, let selected = panel.url {
			installDirectory = selected
			preferences.setInstallDirectory(selected)
			updateInstalledState()
			activityMessage = isInstalled ? "Ready" : "Arknights.exe not found"
		}
	}

	func chooseCustomArtwork() {
		let panel = NSOpenPanel()
		panel.title = "Choose launcher artwork"
		panel.prompt = "Choose"
		panel.allowedContentTypes = [.image]
		panel.canChooseDirectories = false
		panel.canChooseFiles = true
		panel.allowsMultipleSelection = false
		guard panel.runModal() == .OK, let selected = panel.url else { return }

		do {
			try FileManager.default.createDirectory(
				at: paths.customArtwork.deletingLastPathComponent(),
				withIntermediateDirectories: true
			)
			if FileManager.default.fileExists(atPath: paths.customArtwork.path) {
				try FileManager.default.removeItem(at: paths.customArtwork)
			}
			try FileManager.default.copyItem(at: selected, to: paths.customArtwork)
			heroArtwork = NSImage(contentsOf: paths.customArtwork)
		} catch {
			show(error)
		}
	}

	func resetArtwork() {
		try? FileManager.default.removeItem(at: paths.customArtwork)
		activeTask = Task { [weak self] in
			await self?.refresh()
		}
	}

	func openThirdPartyNotices() {
		openBundledDocument(named: "THIRD_PARTY_NOTICES", fileExtension: "md")
	}

	func openProjectLicense() {
		openBundledDocument(named: "LICENSE", fileExtension: nil)
	}

	func openChangelog() {
		openBundledDocument(named: "CHANGELOG", fileExtension: "md")
	}

	func openSourceCode() {
		guard let url = URL(string: "https://github.com/LuMiSxh/ArknightsClient") else { return }
		NSWorkspace.shared.open(url)
	}

	func revealApplication() {
		NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
	}

	func installOrUpdate() {
		startInstallation(launchAfterCompletion: false)
	}

	func repairGame() {
		startInstallation(launchAfterCompletion: false, verifyAllExistingFiles: true)
	}

	private func startInstallation(
		launchAfterCompletion: Bool,
		verifyAllExistingFiles: Bool = false
	) {
		guard let configuration else {
			show(LauncherError.missingConfiguration)
			return
		}
		activeTask?.cancel()
		progress = nil
		phase = .downloading
		activityMessage = verifyAllExistingFiles ? "Verifying…" : "Preparing…"

		activeTask = Task { [weak self] in
			guard let self else { return }
			do {
				let result = try await installer.install(
					configuration: configuration,
					into: installDirectory,
					verifyAllExistingFiles: verifyAllExistingFiles
				) { [weak self] update in
					await MainActor.run {
						self?.progress = update
						self?.activityMessage = "Downloading…"
					}
				}
				isInstalled = true
				installedVersion = configuration.gameLatestVersion
				isGameUpdateAvailable = false
				phase = .ready
				activityMessage = result.downloadedFiles == 0 ? "Ready" : "Updated"
				if launchAfterCompletion { launch() }
			} catch is CancellationError {
				phase = .ready
				activityMessage = "Paused"
			} catch {
				show(error)
			}
		}
	}

	func cancelDownload() {
		activeTask?.cancel()
	}

	func launch() {
		let executable = installDirectory.appending(
			path: configuration?.executableName ?? "Arknights.exe")
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
		activityMessage = "Starting…"
		activeTask = Task { [weak self] in
			guard let self else { return }
			do {
				let processIdentifier = try await runtime.launch(
					gameExecutable: executable,
					prefixDirectory: paths.winePrefix,
					gameArguments: (configuration?.gameStartParams ?? [])
						+ launchOptions.playerArguments,
					logURL: paths.logFile
				)
				phase = .running(processIdentifier: processIdentifier)
				activityMessage = "Running"
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

	func uninstallGame() {
		guard FileManager.default.fileExists(atPath: installDirectory.path) else {
			updateInstalledState()
			return
		}
		let target = installDirectory
		activityMessage = "Moving to Trash…"
		NSWorkspace.shared.recycle([target]) { [weak self] _, error in
			Task { @MainActor in
				guard let self else { return }
				if let error {
					self.show(error)
				} else {
					self.isInstalled = false
					self.installedVersion = nil
					self.isGameUpdateAvailable = false
					self.phase = .ready
					self.activityMessage = "Uninstalled"
				}
			}
		}
	}

	private func updateInstalledState() {
		isInstalled = FileManager.default.fileExists(
			atPath: installDirectory.appending(path: "Arknights.exe").path
		)
		installedVersion = loadInstalledState()?.version
	}

	private func updateGameAvailability() {
		guard isInstalled, let latest = configuration?.gameLatestVersion else {
			isGameUpdateAvailable = false
			return
		}
		isGameUpdateAvailable = installedVersion.map { $0 != latest } ?? true
	}

	private func loadInstalledState() -> InstalledState? {
		let url = installDirectory.appending(path: ".arknights-client-state.json")
		guard let data = try? Data(contentsOf: url) else { return nil }
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .iso8601
		return try? decoder.decode(InstalledState.self, from: data)
	}

	private func loadCustomArtwork() -> Bool {
		guard let image = NSImage(contentsOf: paths.customArtwork) else { return false }
		heroArtwork = image
		return true
	}

	private func openBundledDocument(named name: String, fileExtension: String?) {
		guard let url = Bundle.main.url(forResource: name, withExtension: fileExtension) else {
			return
		}
		NSWorkspace.shared.open(url)
	}

	private func show(_ error: Error) {
		let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
		phase = .failed(message)
		activityMessage = message
	}
}
