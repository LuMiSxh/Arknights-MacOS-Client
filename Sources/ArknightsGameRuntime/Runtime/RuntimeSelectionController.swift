// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameInstallation
import Foundation
import Observation

/// How a lane's installed runtime compares with the version this launcher release pins.
package enum RuntimeLaneState: Equatable, Sendable {
	case notInstalled
	case outdated(installed: String)
	case current
}

/// A runtime operation failure the UI shows inline, with the code the help page uses.
package struct RuntimeSelectionFailure: Equatable, Sendable {
	package let message: String
	package let code: SupportCode?
	package let diagnostic: String

	package init(message: String, code: SupportCode?, diagnostic: String) {
		self.message = message
		self.code = code
		self.diagnostic = diagnostic
	}
}

/// Failures while choosing, installing, or removing a runtime lane.
package enum RuntimeSelectionError: LocalizedError, LauncherDiagnosticError,
	SupportCodeProviding, Equatable, Sendable
{
	case busy
	case laneNotAvailable(RuntimeLane)
	case unavailablePin(RuntimeLane)
	case notInstalled(RuntimeLane)
	case configurationUnavailable(String)
	case verificationFailed(RuntimeLane)
	case installFailed(RuntimeLane, String)
	case removeFailed(RuntimeLane, String)

	package var errorDescription: String? {
		switch self {
		case .busy:
			"Wait for the current operation to finish, then try again."
		case .laneNotAvailable:
			"This Mac cannot run the selected runtime."
		case .unavailablePin:
			"This launcher release does not include a download for the selected runtime."
		case .notInstalled:
			"The selected runtime is not installed. Download it first."
		case .configurationUnavailable:
			"The launcher cannot read its runtime information. Reinstall the launcher."
		case .verificationFailed:
			"The downloaded runtime did not pass verification. Download it again."
		case .installFailed:
			"The runtime could not be installed. Check your connection and free disk space, then try again."
		case .removeFailed:
			"The runtime could not be removed. Close apps that use its files, then try again."
		}
	}

	package var diagnosticDescription: String {
		switch self {
		case .busy:
			"Runtime selection is busy."
		case .laneNotAvailable(let lane):
			"Runtime lane \(lane.rawValue) is not allowed on this macOS version."
		case .unavailablePin(let lane):
			"Runtime lane \(lane.rawValue) has no published pin."
		case .notInstalled(let lane):
			"Runtime lane \(lane.rawValue) is not installed."
		case .configurationUnavailable(let detail):
			"Runtime configuration is unavailable: \(detail)"
		case .verificationFailed(let lane):
			"Runtime lane \(lane.rawValue) failed verification."
		case .installFailed(let lane, let detail):
			"Runtime lane \(lane.rawValue) install failed: \(detail)"
		case .removeFailed(let lane, let detail):
			"Runtime lane \(lane.rawValue) removal failed: \(detail)"
		}
	}

	package var supportCode: SupportCode? {
		switch self {
		case .busy, .laneNotAvailable:
			nil
		case .unavailablePin, .notInstalled:
			.runtimeNotInstalled
		case .configurationUnavailable:
			.bundledRuntimeDamaged
		case .verificationFailed:
			.runtimeVerificationFailed
		case .installFailed:
			.runtimeSetupFailed
		case .removeFailed:
			.localFileFailed
		}
	}

	/// Whether downloading the same lane again can fix the failure.
	package var allowsRetry: Bool {
		switch self {
		case .installFailed, .verificationFailed:
			true
		case .busy, .laneNotAvailable, .unavailablePin, .notInstalled, .configurationUnavailable,
			.removeFailed:
			false
		}
	}

	static func installFailure(_ error: any Error, lane: RuntimeLane) -> Self {
		if let error = error as? RuntimeInstallError {
			switch error {
			case .hashMismatch, .sizeMismatch, .signatureVerificationFailed:
				return .verificationFailed(lane)
			case .runtimeUnavailable:
				return .unavailablePin(lane)
			case .laneNotAllowed:
				return .laneNotAvailable(lane)
			default:
				return .installFailed(lane, launcherDiagnosticDescription(for: error))
			}
		}
		if let error = error as? RuntimeSelectionError { return error }
		return .installFailed(lane, launcherDiagnosticDescription(for: error))
	}
}

/// Copy shared by the setup step and Settings before a lane switch. The warning applies in both
/// directions because each lane owns a separate game environment.
package enum RuntimeSwitchWarning {
	package static let title = "Switch runtime?"
	package static let message =
		"Switching runtimes uses a separate game environment. The game may treat this as a fresh install and ask you to sign in and download resources again. You can switch back later; both game environments stay on disk."

	package static func message(for pin: PinnedRuntime, isInstalled: Bool) -> String {
		var parts = [message]
		if !isInstalled {
			parts.append(
				"The runtime download is about \(DownloadProgressFormatting.byteCount(Int64(pin.sizeBytes)))."
			)
		}
		parts.append("Requires \(pin.minimumMacOS.macOSDisplayName) or later.")
		return parts.joined(separator: " ")
	}
}

/// Owns the selected runtime lane, the installed version of each lane, and the pinned install.
/// There is no version picker or update check: the app release and its `runtime.json` pins move
/// together.
@MainActor
@Observable
package final class RuntimeSelectionController {
	package typealias InstallOperation =
		@Sendable (
			PinnedRuntime, @escaping RuntimeInstaller.ProgressHandler
		) async throws -> InstalledRuntime

	package let paths: AppPaths
	private let selectionStore: RuntimeSelectionStore
	package let lifecycle: LauncherLifecycleStore
	package let access: RuntimeAccess
	/// The lane the launcher uses: the user's override when the OS allows it, otherwise the default.
	package internal(set) var selectedLane: RuntimeLane
	/// The user's lane override from the Danger zone. Nil means the launcher chooses.
	package internal(set) var laneOverride: RuntimeLane?
	package internal(set) var availableLanes: [RuntimeLane]
	package internal(set) var installingLane: RuntimeLane?
	package internal(set) var installProgress: RuntimeInstallProgress?
	/// The lane whose download the user paused. The partial archive stays on disk, so installing
	/// the lane again resumes it. Cleared when the next install starts.
	package internal(set) var pausedLane: RuntimeLane?
	package internal(set) var failure: RuntimeSelectionFailure?

	let log: LauncherLog?
	private let configuration: RuntimeConfiguration?
	private let store: RuntimeStore
	private let installOperation: InstallOperation
	internal var installedVersions: [RuntimeLane: String]
	@ObservationIgnored private var installTask: Task<InstalledRuntime, any Error>?
	/// Owns the running download's outcome. Selecting another lane invalidates it, so a late
	/// completion cannot change the selection or the failure state.
	@ObservationIgnored private let installOwner = TaskSlot()
	@ObservationIgnored private var pauseRequested = false

	#if DEBUG
		/// The real state that a simulation replaces. Restoring it reads nothing from disk.
		@ObservationIgnored var savedRealState: SavedRealState?
	#endif

	package var isInstalling: Bool { installingLane != nil }
	package var isSelectedLaneInstalled: Bool { selectedLaneState == .current }
	package var selectedLaneState: RuntimeLaneState { state(for: selectedLane) }
	/// True while a game launch is pending or a session owns the runtime. Set by the composition root.
	@ObservationIgnored package var isLaunchInProgress: () -> Bool = { false }
	/// Called after a runtime installs, so prefixes of the lane can migrate. Set by the composition root.
	@ObservationIgnored package var onRuntimeInstalled: (() -> Void)?

	/// Whether switching away from the selected lane needs the confirmation. A lane without a game
	/// environment loses no sign-in, so its switch runs without the warning.
	package var switchRequiresWarning: Bool {
		GamePublisher.allCases.contains { publisher in
			FileManager.default.fileExists(
				atPath: paths.winePrefix(for: publisher, lane: selectedLane).path)
		}
	}

	package var installFraction: Double? {
		guard let progress = installProgress, progress.totalBytes > 0 else { return nil }
		return min(max(Double(progress.downloadedBytes) / Double(progress.totalBytes), 0), 1)
	}

	package init(
		paths: AppPaths,
		selectionStore: RuntimeSelectionStore,
		lifecycle: LauncherLifecycleStore,
		log: LauncherLog? = nil,
		access: RuntimeAccess = RuntimeAccess(),
		configuration: RuntimeConfiguration? = nil,
		installOperation: InstallOperation? = nil
	) {
		self.paths = paths
		self.selectionStore = selectionStore
		self.lifecycle = lifecycle
		self.log = log
		self.access = access
		let store = RuntimeStore(paths: paths, selectionStore: selectionStore)
		self.store = store
		log?.attempt("Could not rebuild the runtime record") {
			try store.recoverRecordIfNeeded()
		}
		self.selectedLane = paths.runtimeLane
		self.laneOverride = paths.runtimeLaneOverride
		self.installedVersions = Self.installedVersions(in: store)

		let resolvedConfiguration: RuntimeConfiguration?
		var configurationFailure: RuntimeSelectionError?
		if let configuration {
			resolvedConfiguration = configuration
		} else {
			do {
				resolvedConfiguration = try RuntimeConfiguration.bundled()
			} catch {
				resolvedConfiguration = nil
				configurationFailure = .configurationUnavailable(
					launcherDiagnosticDescription(for: error))
			}
		}
		self.configuration = resolvedConfiguration
		self.availableLanes = Self.offeredLanes(in: resolvedConfiguration, access: access)

		let installer = RuntimeInstaller(
			paths: paths, selectionStore: selectionStore, access: access, log: log)
		self.installOperation =
			installOperation ?? { pin, progress in
				try await installer.install(pin: pin, progress: progress)
			}

		if let configurationFailure {
			present(configurationFailure)
		} else if self.availableLanes.isEmpty {
			present(.unavailablePin(access.defaultLane))
		} else {
			self.failure = nil
		}
	}

	package func installedVersion(for lane: RuntimeLane) -> String? {
		installedVersions[lane]
	}

	/// An installed version counts as usable only when it matches the bundled pin. An install that
	/// lags behind the pin must update before the lane can launch.
	package func state(for lane: RuntimeLane) -> RuntimeLaneState {
		guard let installed = installedVersions[lane] else { return .notInstalled }
		guard let pin = pinnedRuntime(for: lane), pin.version != installed else {
			return .current
		}
		return .outdated(installed: installed)
	}

	/// The pin used for size, version, and macOS requirement copy. A lane with an empty URL,
	/// checksum, or size is not offered.
	package func pinnedRuntime(for lane: RuntimeLane) -> PinnedRuntime? {
		#if DEBUG
			if savedRealState != nil { return Self.simulatedPin(for: lane) }
		#endif
		guard let configuration else { return nil }
		do {
			return try configuration.pinnedRuntime(for: lane)
		} catch {
			log?.error(
				"Runtime pin unavailable; lane=\(lane.rawValue); \(launcherDiagnosticDescription(for: error))"
			)
			return nil
		}
	}

	package func refresh() {
		log?.attempt("Could not rebuild the runtime record") {
			try store.recoverRecordIfNeeded()
		}
		installedVersions = Self.installedVersions(in: store)
		availableLanes = Self.offeredLanes(in: configuration, access: access)
		do {
			let selection = try selectionStore.load()
			selectedLane = selection.effectiveLane(access: access)
			laneOverride = selection.validOverride(access: access)
		} catch {
			log?.error(
				"Runtime selection could not be read; \(launcherDiagnosticDescription(for: error))")
		}
	}

	package func clearFailure() {
		failure = nil
		if lifecycle.state.presentation.failure?.context.operation == .runtimeSetup {
			lifecycle.clearFailure()
		}
	}

	/// Downloads and installs the pin of `lane`. A lane other than the effective one becomes the
	/// override first. The lane stays selected while its download runs, pauses, or fails, so Home
	/// shows runtime setup instead of Play. Game installation may run at the same time because the
	/// two downloads write to different trees. Any other activity waits.
	@discardableResult
	package func install(lane: RuntimeLane) async -> Bool {
		guard installingLane == nil,
			lifecycle.activity == .idle || lifecycle.activity.isInstalling
		else { return false }
		clearFailure()
		guard access.allows(lane) else {
			present(.laneNotAvailable(lane))
			return false
		}
		guard let configuration else {
			present(.configurationUnavailable("no bundled configuration"))
			return false
		}
		let pin: PinnedRuntime
		do {
			pin = try configuration.pinnedRuntime(for: lane)
		} catch {
			present(.configurationUnavailable(launcherDiagnosticDescription(for: error)))
			return false
		}
		guard pin.isAvailable else {
			present(.unavailablePin(lane))
			return false
		}

		do {
			try selectForDownload(lane: lane)
		} catch {
			return false
		}

		installingLane = lane
		installProgress = nil
		pausedLane = nil
		pauseRequested = false
		let token = installOwner.begin()
		defer {
			installingLane = nil
			installProgress = nil
			installTask = nil
			if installOwner.owns(token) { installOwner.invalidate() }
		}
		log?.info("Runtime install started; lane=\(lane.rawValue) version=\(pin.version)")

		// The operation runs in its own task so a pause can cancel it. Awaiting its value means the
		// installer's lease and file handles are released before this method returns, even on cancel.
		let operation = installOperation
		let task = Task { [weak self] in
			try await operation(pin) { progress in
				await MainActor.run {
					self?.receive(progress, for: lane)
				}
			}
		}
		installTask = task

		do {
			let installed = try await withTaskCancellationHandler {
				try await task.value
			} onCancel: {
				task.cancel()
			}
			log?.info("Runtime installed; lane=\(lane.rawValue) version=\(installed.version)")
			do {
				try store.recordInstalled(lane: installed.lane, version: installed.version)
			} catch {
				present(.installFailure(error, lane: lane))
				refresh()
				return false
			}
			refresh()
			if installOwner.owns(token) { onRuntimeInstalled?() }
			return installOwner.owns(token)
		} catch is CancellationError {
			// A pause is not a failure: the partial archive stays and no failure is presented.
			// Pausing before the first byte leaves nothing to resume, so the lane stays not installed.
			if pauseRequested, hasPartialArchive(for: pin) { pausedLane = lane }
			log?.info("Runtime install cancelled; lane=\(lane.rawValue) paused=\(pauseRequested)")
			return false
		} catch {
			guard installOwner.owns(token) else {
				log?.info("Runtime install failure ignored; lane=\(lane.rawValue); superseded")
				return false
			}
			present(.installFailure(error, lane: lane))
			refresh()
			return false
		}
	}

	private func hasPartialArchive(for pin: PinnedRuntime) -> Bool {
		let url = RuntimeInstaller.partialArchiveURL(for: pin, paths: paths)
		do {
			let size = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64
			return (size ?? 0) > 0
		} catch let error as CocoaError where error.code == .fileNoSuchFile {
			return false
		} catch {
			log?.error(
				"Could not inspect the partial runtime archive: \(error.localizedDescription)")
			return false
		}
	}

	/// Makes `lane` the effective lane when it may not be installed yet, so a download of it can
	/// start. Home then shows the runtime setup state until the download completes. The effective
	/// lane itself needs no write. Refused while a game launch or any activity other than a game
	/// installation is in progress.
	package func selectForDownload(lane: RuntimeLane) throws {
		guard lifecycle.activity == .idle || lifecycle.activity.isInstalling,
			installingLane == nil, !isLaunchInProgress()
		else {
			let error = RuntimeSelectionError.busy
			present(error)
			throw error
		}
		guard availableLanes.contains(lane) else {
			let error = RuntimeSelectionError.laneNotAvailable(lane)
			present(error)
			throw error
		}
		if lane != selectedLane { try commitSelection(of: lane) }
	}

	/// Pauses the running download. The installer keeps its `.part` archive, so installing the
	/// lane again resumes from the bytes already on disk. Does nothing outside the download phase.
	package func pauseInstall() {
		guard installingLane != nil, let task = installTask,
			installProgress == nil || installProgress?.phase == .downloading
		else { return }
		pauseRequested = true
		task.cancel()
	}

	/// Sets the lane override, or clears it with nil so the launcher chooses again. A lane must be
	/// installed. The automatic lane may not be: Home then offers its setup.
	package func select(override lane: RuntimeLane?) throws {
		guard lifecycle.activity == .idle, !isLaunchInProgress() else {
			throw RuntimeSelectionError.busy
		}
		if let lane {
			guard availableLanes.contains(lane) else {
				let error = RuntimeSelectionError.laneNotAvailable(lane)
				present(error)
				throw error
			}
			guard state(for: lane) == .current else {
				let error = RuntimeSelectionError.notInstalled(lane)
				present(error)
				throw error
			}
		}
		// Leaving a lane mid-download abandons that download. Its partial archive stays on disk.
		if installingLane != nil {
			installOwner.invalidate()
			installTask?.cancel()
		}
		try commitSelection(of: lane)
	}

	private func commitSelection(of lane: RuntimeLane?) throws {
		let effective = lane ?? access.defaultLane
		do {
			try store.select(override: lane, access: access)
		} catch {
			let error = RuntimeSelectionError.installFailed(
				effective, launcherDiagnosticDescription(for: error))
			present(error)
			throw error
		}
		laneOverride = lane
		selectedLane = effective
		clearFailure()
		log?.info(
			"Runtime lane selected; lane=\(effective.rawValue) override=\(lane?.rawValue ?? "none")"
		)
	}

	/// Removes the lane that is not selected. The selected lane is never touched.
	package func removeOtherLane() async throws {
		guard let other = RuntimeLane.allCases.first(where: { $0 != selectedLane }) else { return }
		try await removeRuntime(lane: other, allowSelected: false)
	}

	/// Removes the selected lane's runtime. Its game environment and the selection stay.
	package func removeSelectedLane() async throws {
		try await removeRuntime(lane: selectedLane, allowSelected: true)
	}

	// MARK: - Private

	@concurrent
	private static func removeRuntime(
		lane: RuntimeLane, allowSelected: Bool, store: RuntimeStore, access: RuntimeAccess
	) async throws {
		try store.remove(lane: lane, allowSelected: allowSelected, access: access)
	}

	/// Holds the maintenance lease for the whole removal, so no game session, install, or other
	/// maintenance runs while the lane directory goes.
	private func removeRuntime(lane: RuntimeLane, allowSelected: Bool) async throws {
		guard installingLane == nil,
			let lease = lifecycle.begin(.maintaining(.removingRuntime))
		else {
			throw RuntimeSelectionError.busy
		}
		defer { lifecycle.end(lease) }
		failure = nil
		do {
			try await Self.removeRuntime(
				lane: lane, allowSelected: allowSelected, store: store, access: access)
		} catch {
			let error = RuntimeSelectionError.removeFailed(
				lane, launcherDiagnosticDescription(for: error))
			present(error)
			refresh()
			throw error
		}
		refresh()
		log?.info("Runtime removed; lane=\(lane.rawValue)")
	}

	private func present(_ error: RuntimeSelectionError) {
		let failure = Self.failure(for: error)
		self.failure = failure
		log?.error(
			"Runtime selection failed; code=\(failure.code?.rawValue ?? "none"); \(failure.diagnostic)"
		)
		// Presented through the shared lifecycle so Home shows the same failure sheet as game failures.
		lifecycle.presentFailure(
			message: failure.message,
			id: UUID(),
			code: failure.code,
			context: SupportContext(operation: .runtimeSetup, region: nil),
			canRepair: false,
			allowsRetry: error.allowsRetry,
			blocksGameLaunch: true,
			diagnostic: failure.diagnostic
		)
	}

	// The installer rate-limits byte snapshots and always passes phase, stall and final ones,
	// so forwarding every snapshot keeps those changes immediate.
	private func receive(_ progress: RuntimeInstallProgress, for lane: RuntimeLane) {
		guard installingLane == lane else { return }
		installProgress = progress
	}

	private static func installedVersions(in store: RuntimeStore) -> [RuntimeLane: String] {
		var versions: [RuntimeLane: String] = [:]
		for lane in RuntimeLane.allCases {
			if let version = store.installedVersion(for: lane) {
				versions[lane] = version
			}
		}
		return versions
	}

	private static func offeredLanes(
		in configuration: RuntimeConfiguration?,
		access: RuntimeAccess
	) -> [RuntimeLane] {
		guard let configuration else { return [] }
		return RuntimeLane.allCases.filter { lane in
			guard access.allows(lane) else { return false }
			do {
				return try configuration.pinnedRuntime(for: lane).isAvailable
			} catch {
				return false
			}
		}
	}

	static func failure(for error: RuntimeSelectionError) -> RuntimeSelectionFailure {
		RuntimeSelectionFailure(
			message: error.errorDescription ?? "The runtime operation failed.",
			code: error.supportCode,
			diagnostic: error.diagnosticDescription
		)
	}
}
