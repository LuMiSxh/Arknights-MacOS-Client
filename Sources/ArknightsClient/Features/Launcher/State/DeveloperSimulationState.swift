// SPDX-License-Identifier: MPL-2.0

#if DEBUG
	import Foundation

	enum DeveloperPreviewLifecycle: String, CaseIterable, Equatable, Identifiable, Sendable {
		case ready
		case installing
		case paused
		case launching
		case running

		var id: String { rawValue }

		var title: String {
			switch self {
			case .ready: "Ready"
			case .installing: "Installing"
			case .paused: "Paused"
			case .launching: "Launching"
			case .running: "Running"
			}
		}
	}

	enum DeveloperPreviewProgressMode: String, CaseIterable, Equatable, Identifiable, Sendable {
		case known
		case unknown

		var id: String { rawValue }

		var title: String {
			switch self {
			case .known: "Known values"
			case .unknown: "Unknown values"
			}
		}
	}

	enum DeveloperPreviewTransferRateMode: String, CaseIterable, Equatable, Identifiable, Sendable {
		case known
		case unknown

		var id: String { rawValue }

		var title: String {
			switch self {
			case .known: "Known speed"
			case .unknown: "Unknown speed"
			}
		}
	}

	enum DeveloperPreviewInstallationPhase: String, CaseIterable, Equatable, Identifiable, Sendable
	{
		case preparing
		case verifying
		case downloading
		case pausing

		var id: String { rawValue }

		var title: String {
			switch self {
			case .preparing: "Preparing"
			case .verifying: "Verifying"
			case .downloading: "Downloading"
			case .pausing: "Pausing"
			}
		}

		var state: InstallationStage {
			switch self {
			case .preparing: .preparing
			case .verifying: .verifying
			case .downloading: .downloading
			case .pausing: .pausing
			}
		}

		var status: LauncherStatus {
			switch self {
			case .preparing: .preparingInstallation
			case .verifying: .verifyingInstallation
			case .downloading: .downloading
			case .pausing: .pausing
			}
		}
	}

	enum DeveloperPreviewLauncherUpdate: String, CaseIterable, Equatable, Identifiable, Sendable {
		case current
		case available
		case failed

		var id: String { rawValue }

		var title: String {
			switch self {
			case .current: "Current"
			case .available: "Update available"
			case .failed: "Check failed"
			}
		}
	}

	enum DeveloperPreviewFailure: String, CaseIterable, Equatable, Identifiable, Sendable {
		case none
		case runtime
		case configuration

		var id: String { rawValue }

		var title: String {
			switch self {
			case .none: "No failure"
			case .runtime: "Runtime failure"
			case .configuration: "Configuration failure"
			}
		}

		var operation: SupportOperation? {
			switch self {
			case .none: nil
			case .runtime: .runtimeExit
			case .configuration: .configurationRefresh
			}
		}
	}

	enum DeveloperPreviewPopup: String, CaseIterable, Equatable, Identifiable, Sendable {
		case none
		case announcement
		case custom

		var id: String { rawValue }

		var title: String {
			switch self {
			case .none: "Hidden"
			case .announcement: "Announcement"
			case .custom: "Custom Markdown"
			}
		}
	}

	enum DeveloperPreviewPill: String, CaseIterable, Equatable, Identifiable, Sendable {
		case none
		case music
		case version
		case status

		var id: String { rawValue }

		var title: String {
			switch self {
			case .none: "Collapsed"
			case .music: "Music"
			case .version: "Version"
			case .status: "Server reset"
			}
		}
	}

	struct DeveloperSimulationState: Equatable, Sendable {
		var lifecycle: DeveloperPreviewLifecycle = .ready
		var isInstalled = true
		var hasPartialDownload = false
		var installationPhase: DeveloperPreviewInstallationPhase = .downloading
		var progressMode: DeveloperPreviewProgressMode = .known
		var transferRateMode: DeveloperPreviewTransferRateMode = .known
		var transferRateBytesPerSecond: Double = 3_500_000
		var transferStalled = false
		var downloadedBytes: Int64 = 15_210_000_000
		var totalBytes: Int64 = 22_280_000_000
		var completedFiles = 128
		var totalFiles = 291
		var currentFile = "Arknights_Data/data.unity3d"
		var updateAvailable = false
		var launcherUpdate: DeveloperPreviewLauncherUpdate = .current
		var failure: DeveloperPreviewFailure = .none
		var failureCode: SupportCode = .crux
		var selectedRegion: GameRegion = .global
		var canaryFeaturesEnabled = false
		var chinaClientsEnabled = false
		var taiwanClientEnabled = false
		var installedRegions: Set<GameRegion> = [.global]
		var showStatusPill = false
		var showVersionPill = true
		var showMusicPill = false
		var expandedPill: DeveloperPreviewPill = .none
		var popup: DeveloperPreviewPopup = .none
		var customPopupTitle = "Developer preview popup"
		var customPopupMarkdown = "This popup is injected by the debug simulator."
		var onboardingPreview = false
		var rosettaMissing = false
		var longAccessibilityText = false
		var usesDynamicTheme = true

		var progressPercent: Double {
			get {
				guard totalBytes > 0 else { return 0 }
				return min(1, max(0, Double(downloadedBytes) / Double(totalBytes)))
			}
			set {
				let fraction = min(max(newValue, 0), 1)
				downloadedBytes = Int64(Double(max(totalBytes, 1)) * fraction)
			}
		}

		static func isPreviewArgument(_ arguments: [String]) -> Bool {
			arguments.contains("--developer-preview")
		}

		var selectableRegions: [GameRegion] {
			GameRegion.selectableCases(
				canaryEnabled: canaryFeaturesEnabled,
				chinaClientsEnabled: chinaClientsEnabled,
				taiwanClientEnabled: taiwanClientEnabled
			)
		}

		/// Keeps combinations shown by the simulator meaningful before they reach production
		/// controllers. This is deliberately a value transform so bindings can apply it once.
		func normalized() -> Self {
			var normalized = self
			let selectable = Set(normalized.selectableRegions)
			if !selectable.contains(normalized.selectedRegion) {
				normalized.selectedRegion = .global
			}
			normalized.installedRegions.formIntersection(selectable)
			normalized.totalBytes = max(normalized.totalBytes, 1)
			normalized.downloadedBytes = min(
				max(normalized.downloadedBytes, 0), normalized.totalBytes)
			normalized.completedFiles = max(normalized.completedFiles, 0)
			normalized.totalFiles = max(normalized.totalFiles, normalized.completedFiles)
			if normalized.currentFile.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
				normalized.currentFile = "Arknights_Data/data.unity3d"
			}
			normalized.transferRateBytesPerSecond = max(
				normalized.transferRateBytesPerSecond.isFinite
					? normalized.transferRateBytesPerSecond
					: 0,
				0
			)
			if normalized.lifecycle == .paused {
				normalized.hasPartialDownload = true
			}
			if normalized.isInstalled {
				normalized.installedRegions.insert(normalized.selectedRegion)
			} else {
				normalized.installedRegions.remove(normalized.selectedRegion)
				normalized.updateAvailable = false
			}
			if normalized.lifecycle == .launching || normalized.lifecycle == .running {
				normalized.isInstalled = true
				normalized.installedRegions.insert(normalized.selectedRegion)
				normalized.hasPartialDownload = false
				normalized.updateAvailable = false
			}
			return normalized
		}

		func projection() -> DeveloperSimulationProjection {
			let progress: DownloadProgress?
			if progressMode == .known,
				lifecycle == .installing || lifecycle == .paused
					|| (lifecycle == .ready && hasPartialDownload)
			{
				let total = max(totalBytes, 1)
				let downloaded = min(max(downloadedBytes, 0), total)
				progress = DownloadProgress(
					downloadedBytes: downloaded,
					totalBytes: total,
					completedFiles: max(completedFiles, 0),
					totalFiles: max(totalFiles, 0),
					currentFile: currentFile,
					transferRateBytesPerSecond: transferRateMode == .known
						? transferRateBytesPerSecond
						: nil,
					isTransferStalled: transferStalled
				)
			} else {
				progress = nil
			}

			let status: LauncherStatus
			switch lifecycle {
			case .ready:
				status =
					updateAvailable
					? .updateAvailable
					: (isInstalled ? .ready : (hasPartialDownload ? .paused : .install))
			case .installing: status = installationPhase.status
			case .paused: status = .paused
			case .launching: status = .startingGame
			case .running: status = .running
			}

			let launcherUpdateVersion = launcherUpdate == .available ? "0.6.1" : nil
			let launcherUpdateStatus: String
			switch launcherUpdate {
			case .current: launcherUpdateStatus = "Up to date"
			case .available: launcherUpdateStatus = "Version 0.6.1 available"
			case .failed: launcherUpdateStatus = "Couldn’t check for updates"
			}

			return DeveloperSimulationProjection(
				lifecycle: lifecycle,
				status: status,
				isInstalled: isInstalled,
				hasPartialDownload: hasPartialDownload,
				installedVersion: isInstalled ? (updateAvailable ? "041.2.0" : "042.0.0") : nil,
				isGameUpdateAvailable: updateAvailable,
				progress: progress,
				launcherUpdateVersion: launcherUpdateVersion,
				launcherUpdateStatus: launcherUpdateStatus,
				failureCode: failure == .none ? nil : failureCode,
				failureOperation: failure.operation
			)
		}
	}

	struct DeveloperSimulationProjection: Equatable, Sendable {
		let lifecycle: DeveloperPreviewLifecycle
		let status: LauncherStatus
		let isInstalled: Bool
		let hasPartialDownload: Bool
		let installedVersion: String?
		let isGameUpdateAvailable: Bool
		let progress: DownloadProgress?
		let launcherUpdateVersion: String?
		let launcherUpdateStatus: String
		let failureCode: SupportCode?
		let failureOperation: SupportOperation?
	}
#endif
