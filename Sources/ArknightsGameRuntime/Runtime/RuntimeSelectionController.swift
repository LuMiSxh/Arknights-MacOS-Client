// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
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
			"This Mac cannot run the selected runtime architecture."
		case .unavailablePin:
			"This launcher release does not include a download for the selected runtime architecture."
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
	package static let title = "Switch runtime architecture?"
	package static let message =
		"Switching architectures uses a separate game environment. The game may treat this as a fresh install and ask you to sign in and download resources again. You can switch back later; both game environments stay on disk."

	package static func message(for pin: PinnedRuntime, isInstalled: Bool) -> String {
		var parts = [message]
		if !isInstalled {
			parts.append(
				"The runtime download is about \(ByteCountFormatter.string(fromByteCount: Int64(pin.sizeBytes), countStyle: .file))."
			)
		}
		parts.append("Requires \(macOSVersion(pin.minimumMacOS)) or later.")
		return parts.joined(separator: " ")
	}

	private static func macOSVersion(_ version: OperatingSystemVersion) -> String {
		version.minorVersion == 0
			? "macOS \(version.majorVersion)"
			: "macOS \(version.majorVersion).\(version.minorVersion)"
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
	package let lifecycle: LauncherLifecycleStore
	package let access: RuntimeAccess
	package private(set) var selectedLane: RuntimeLane
	package private(set) var availableLanes: [RuntimeLane]
	package private(set) var installingLane: RuntimeLane?
	package private(set) var installProgress: RuntimeInstallProgress?
	package private(set) var failure: RuntimeSelectionFailure?

	let log: LauncherLog?
	private let configuration: RuntimeConfiguration?
	private let store: RuntimeStore
	private let installOperation: InstallOperation
	private var installedVersions: [RuntimeLane: String]
	@ObservationIgnored private var lastProgressUpdate: ContinuousClock.Instant?

	package var isInstalling: Bool { installingLane != nil }
	package var isSelectedLaneInstalled: Bool { selectedLaneState == .current }
	package var selectedLaneState: RuntimeLaneState { state(for: selectedLane) }
	/// True after `select` persists a lane that this process cannot use until it starts again.
	package var requiresRelaunch: Bool { selectedLane != paths.runtimeLane }
	package var allowsX86: Bool { access.allows(.x86) }
	package var allowsARM64: Bool { access.allows(.arm) }

	package var installFraction: Double? {
		guard let progress = installProgress, progress.totalBytes > 0 else { return nil }
		return min(max(Double(progress.downloadedBytes) / Double(progress.totalBytes), 0), 1)
	}

	package init(
		paths: AppPaths,
		lifecycle: LauncherLifecycleStore,
		log: LauncherLog? = nil,
		access: RuntimeAccess = RuntimeAccess(),
		configuration: RuntimeConfiguration? = nil,
		installOperation: InstallOperation? = nil
	) {
		self.paths = paths
		self.lifecycle = lifecycle
		self.log = log
		self.access = access
		let store = RuntimeStore(paths: paths)
		self.store = store
		self.selectedLane = paths.runtimeLane
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

		let installer = RuntimeInstaller(paths: paths, access: access, log: log)
		self.installOperation =
			installOperation ?? { pin, progress in
				try await installer.install(pin: pin, progress: progress)
			}

		if let configurationFailure {
			self.failure = Self.failure(for: configurationFailure)
			log?.error(
				"Runtime selection failed; code=\(self.failure?.code?.rawValue ?? "none"); \(configurationFailure.diagnosticDescription)"
			)
		} else if self.availableLanes.isEmpty {
			let error = RuntimeSelectionError.unavailablePin(access.defaultLane)
			self.failure = Self.failure(for: error)
			log?.error(
				"Runtime selection failed; code=\(self.failure?.code?.rawValue ?? "none"); \(error.diagnosticDescription)"
			)
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
		installedVersions = Self.installedVersions(in: store)
		availableLanes = Self.offeredLanes(in: configuration, access: access)
		do {
			selectedLane = try RuntimeSelectionStore(fileURL: paths.runtimeSelectionFile).load(
				access: access
			).selected
		} catch {
			log?.error(
				"Runtime selection could not be read; \(launcherDiagnosticDescription(for: error))")
		}
	}

	package func clearFailure() {
		failure = nil
	}

	/// Downloads and installs the lane pin, then selects the lane. Game installation may run at
	/// the same time because the two downloads write to different trees. Any other activity waits.
	@discardableResult
	package func install(lane: RuntimeLane) async -> Bool {
		guard installingLane == nil,
			lifecycle.activity == .idle || lifecycle.activity.isInstalling
		else { return false }
		failure = nil
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

		installingLane = lane
		installProgress = nil
		lastProgressUpdate = nil
		defer {
			installingLane = nil
			installProgress = nil
			lastProgressUpdate = nil
		}
		log?.info("Runtime install started; lane=\(lane.rawValue) version=\(pin.version)")

		do {
			let installed = try await installOperation(pin) { [weak self] progress in
				await MainActor.run {
					self?.receive(progress, for: lane)
				}
			}
			log?.info("Runtime installed; lane=\(lane.rawValue) version=\(installed.version)")
			try store.select(lane: lane, access: access)
			selectedLane = lane
			refresh()
			return true
		} catch is CancellationError {
			log?.info("Runtime install cancelled; lane=\(lane.rawValue)")
			return false
		} catch {
			present(.installFailure(error, lane: lane))
			refresh()
			return false
		}
	}

	package func select(lane: RuntimeLane) throws {
		guard lifecycle.activity == .idle, installingLane == nil else {
			throw RuntimeSelectionError.busy
		}
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
		do {
			try store.select(lane: lane, access: access)
		} catch {
			let error = RuntimeSelectionError.installFailed(
				lane, launcherDiagnosticDescription(for: error))
			present(error)
			throw error
		}
		selectedLane = lane
		failure = nil
		log?.info(
			"Runtime lane selected; lane=\(lane.rawValue); relaunch=\(requiresRelaunch)")
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
		lane: RuntimeLane, allowSelected: Bool, store: RuntimeStore
	) async throws {
		try store.remove(lane: lane, allowSelected: allowSelected)
	}

	/// Holds the maintenance lease for the whole removal, so no game session, install, or other
	/// maintenance runs while the lane directory goes.
	private func removeRuntime(lane: RuntimeLane, allowSelected: Bool) async throws {
		guard installingLane == nil, !requiresRelaunch,
			let lease = lifecycle.begin(.maintaining(.removingRuntime))
		else {
			throw RuntimeSelectionError.busy
		}
		defer { lifecycle.end(lease) }
		failure = nil
		do {
			try await Self.removeRuntime(lane: lane, allowSelected: allowSelected, store: store)
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
	}

	private func receive(_ progress: RuntimeInstallProgress, for lane: RuntimeLane) {
		guard installingLane == lane else { return }
		let phaseChanged = installProgress?.phase != progress.phase
		let now = ContinuousClock().now
		if !phaseChanged, let lastProgressUpdate,
			now - lastProgressUpdate < AppConstants.Network.progressEmissionInterval
		{
			return
		}
		lastProgressUpdate = now
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

	private static func failure(for error: RuntimeSelectionError) -> RuntimeSelectionFailure {
		RuntimeSelectionFailure(
			message: error.errorDescription ?? "The runtime operation failed.",
			code: error.supportCode,
			diagnostic: error.diagnosticDescription
		)
	}
}
