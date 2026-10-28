// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameInstallation

#if DEBUG
	package struct DeveloperSimulationState: Equatable, Sendable {
		// String raw values keep these CaseIterable choices usable by the generic developer picker.
		enum Lifecycle: String, CaseIterable { case ready, installing, paused, launching, running }
		enum Phase: String, CaseIterable { case preparing, verifying, downloading, pausing }
		enum Progress: String, CaseIterable {
			case unknown, early, half, late

			var fraction: Double {
				switch self {
				case .unknown: 0
				case .early: 0.15
				case .half: 0.42
				case .late: 0.9
				}
			}
		}
		enum Transfer: String, CaseIterable { case known, unknown, stalled }
		enum LauncherUpdate: String, CaseIterable { case current, available, failed }
		enum Failure: String, CaseIterable {
			case none, runtime, configuration

			var operation: SupportOperation? {
				switch self {
				case .none: nil
				case .runtime: .runtimeExit
				case .configuration: .configurationRefresh
				}
			}
		}
		// The raw value is the pill identifier `LauncherHUDView` expands.
		enum Pill: String, CaseIterable { case none, music, version, status }

		static let launcherUpdateVersion = "0.6.1"

		var lifecycle = Lifecycle.ready
		var phase = Phase.downloading
		var progress = Progress.half
		var transfer = Transfer.known
		var hasPartialDownload = false
		var updateAvailable = false
		var launcherUpdate = LauncherUpdate.current
		var failure = Failure.none
		var failureCode = SupportCode.gameClosedUnexpectedly
		var selectedRegion = GameRegion.global
		var installedRegions: Set<GameRegion> = [.global]
		var canaryFeaturesEnabled = false
		var taiwanClientEnabled = false
		var showStatusPill = false
		var showVersionPill = true
		var showMusicPill = false
		var expandedPill = Pill.none
		var announcement = false
		var onboardingPreview = false
		var onboardingRequired = false
		var rosettaMissing = false
		var xcodeMissing = false
		var longAccessibilityText = false
		var usesDynamicTheme = true

		package static func isPreviewArgument(_ arguments: [String]) -> Bool {
			arguments.contains("--developer-preview")
		}

		var isInstalled: Bool {
			get { installedRegions.contains(selectedRegion) }
			set {
				if newValue {
					installedRegions.insert(selectedRegion)
				} else {
					installedRegions.remove(selectedRegion)
				}
			}
		}

		var selectableRegions: [GameRegion] {
			RegionAccess(
				canaryFeaturesEnabled: canaryFeaturesEnabled,
				taiwanClientEnabled: taiwanClientEnabled
			).selectableRegions
		}

		/// Removes combinations the launcher cannot reach, so controllers never see them.
		func normalized() -> Self {
			var normalized = self
			let selectable = Set(selectableRegions)
			if !selectable.contains(selectedRegion) { normalized.selectedRegion = .global }
			normalized.installedRegions.formIntersection(selectable)
			if lifecycle == .paused { normalized.hasPartialDownload = true }
			if lifecycle == .launching || lifecycle == .running {
				normalized.isInstalled = true
				normalized.hasPartialDownload = false
			}
			if !normalized.isInstalled || lifecycle == .launching || lifecycle == .running {
				normalized.updateAvailable = false
			}
			return normalized
		}

		var downloadProgress: DownloadProgress? {
			let isVerifying = phase == .verifying
			// A stopped verification pass does not represent partial-download progress.
			guard progress != .unknown, !isVerifying || lifecycle == .installing,
				lifecycle == .installing || lifecycle == .paused
					|| (lifecycle == .ready && hasPartialDownload)
			else { return nil }
			let totalBytes: Int64 = 22_280_000_000
			let totalFiles = 291
			return DownloadProgress(
				downloadedBytes: Int64((Double(totalBytes) * progress.fraction).rounded()),
				totalBytes: totalBytes,
				completedFiles: Int(Double(totalFiles) * progress.fraction),
				totalFiles: totalFiles,
				currentFile: "Arknights_Data/data.unity3d",
				transferRateBytesPerSecond: !isVerifying && transfer == .known ? 3_500_000 : nil,
				isTransferStalled: !isVerifying && transfer == .stalled,
				isVerifying: isVerifying
			)
		}

		var status: LauncherStatus {
			switch lifecycle {
			case .ready:
				if updateAvailable {
					.updateAvailable
				} else if isInstalled {
					.ready
				} else {
					hasPartialDownload ? .paused : .install
				}
			case .installing:
				switch phase {
				case .preparing: .preparingInstallation
				case .verifying: .verifyingInstallation
				case .downloading: .downloading
				case .pausing: .pausing
				}
			case .paused: .paused
			case .launching: .startingGame
			case .running: .running
			}
		}

		var installedVersion: String? {
			isInstalled ? (updateAvailable ? "041.2.0" : "042.0.0") : nil
		}

		var launcherUpdateVersion: String? {
			launcherUpdate == .available ? Self.launcherUpdateVersion : nil
		}

		var launcherUpdateStatus: String {
			switch launcherUpdate {
			case .current: "Up to date"
			case .available: "Version \(Self.launcherUpdateVersion) available"
			case .failed: "Couldn’t check for updates"
			}
		}

		var installationStage: InstallationStage {
			switch phase {
			case .preparing: .preparing
			case .verifying: .verifying
			case .downloading: .downloading
			case .pausing: .pausing
			}
		}
	}
#endif
