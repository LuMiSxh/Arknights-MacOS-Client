// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameInstallation
import CoreGraphics

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
		enum Runtime: String, CaseIterable {
			case real, notInstalled, installed, installing, failed
		}
		// The raw value is the pill identifier `LauncherHUDView` expands.
		enum Pill: String, CaseIterable { case none, music, version, status }
		// Adds a simulated display to the Game display row only. Launches never read it.
		enum Displays: String, CaseIterable { case system, twoDisplays }

		static let launcherUpdateVersion = "0.6.1"
		// Only the Game display row reads this. A saved choice of it is not connected at launch.
		static let simulatedDisplay = GameScreenInfo(
			displayID: 0x7FFF_0001,
			identity: GameDisplayIdentity(
				uuid: "6F1A2B3C-4D5E-4F60-8A7B-9C0D1E2F3A4B", name: "Simulated Display"),
			frameSize: CGSize(width: 1920, height: 1080),
			visibleSize: CGSize(width: 1920, height: 1080),
			backingScaleFactor: 2,
			notchHeight: 0)

		var lifecycle = Lifecycle.ready
		var phase = Phase.downloading
		var progress = Progress.half
		var transfer = Transfer.known
		var hasPartialDownload = false
		var updateAvailable = false
		var launcherUpdate = LauncherUpdate.current
		var failure = Failure.none
		var failureCode = SupportCode.gameClosedUnexpectedly
		var runtime = Runtime.real
		var selectedRegion = GameRegion.global
		var installedRegions: Set<GameRegion> = [.global]
		var canaryFeaturesEnabled = false
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
		// The preview starts with a second display so the Game display row is visible.
		var displays = Displays.twoDisplays

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
			RegionAccess(canaryFeaturesEnabled: canaryFeaturesEnabled).selectableRegions
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

		/// The Game display list with the simulated display added, or nil when none is simulated.
		func simulatedGameScreens() -> GameScreenList? {
			guard displays == .twoDisplays else { return nil }
			return GameScreenList.system().adding(Self.simulatedDisplay)
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
