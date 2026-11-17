// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation

#if DEBUG
	extension RuntimeSelectionController {
		/// A developer-preview runtime state. The controller mirrors it in memory only.
		package enum SimulatedState: Sendable {
			case notInstalled, installed, installing, failed
		}

		/// The real state that a simulation replaces. Restoring it reads nothing from disk.
		struct SavedRealState {
			let availableLanes: [RuntimeLane]
			let installedVersions: [RuntimeLane: String]
			let selectedLane: RuntimeLane
			let failure: RuntimeSelectionFailure?
		}

		/// Mirrors a developer-preview runtime state in memory. `nil` restores the real state.
		/// Never reads the bundled configuration, touches the selection file, or downloads.
		package func simulate(_ state: SimulatedState?) {
			guard let state else {
				restoreRealState()
				return
			}
			if savedRealState == nil {
				savedRealState = SavedRealState(
					availableLanes: availableLanes,
					installedVersions: installedVersions,
					selectedLane: selectedLane,
					failure: failure
				)
			}
			let lanes = RuntimeLane.allCases.filter(access.allows)
			let installed = Dictionary(
				uniqueKeysWithValues: lanes.map { ($0, Self.simulatedVersion) })
			let failed = Self.failure(for: .installFailed(selectedLane, "Developer preview"))
			availableLanes = lanes
			installedVersions = state == .installed ? installed : [:]
			installingLane = state == .installing ? selectedLane : nil
			pausedLane = nil
			installProgress = state == .installing ? Self.simulatedProgress : nil
			failure = state == .failed ? failed : nil
		}

		/// Mirrors a paused download in memory only, for the developer preview.
		package func simulatePause() {
			guard let lane = installingLane else { return }
			pausedLane = lane
			installingLane = nil
			installProgress = nil
		}

		/// Selects a lane in memory only, for the developer preview.
		package func simulateSelect(lane: RuntimeLane) {
			selectedLane = lane
		}

		private func restoreRealState() {
			guard let saved = savedRealState else { return }
			savedRealState = nil
			availableLanes = saved.availableLanes
			installedVersions = saved.installedVersions
			selectedLane = saved.selectedLane
			failure = saved.failure
			installingLane = nil
			installProgress = nil
			pausedLane = nil
		}

		private static let simulatedVersion = "1.0.0-sim"
		private static let simulatedProgress = RuntimeInstallProgress(
			downloadedBytes: 11_000_000_000,
			totalBytes: 22_000_000_000,
			phase: .downloading,
			transferRateBytesPerSecond: 3_500_000
		)

		static func simulatedPin(for lane: RuntimeLane) -> PinnedRuntime {
			PinnedRuntime(
				lane: lane,
				name: "Simulated runtime",
				version: simulatedVersion,
				url: URL(string: "https://runtime.invalid/simulated.tar.zst"),
				sha256: String(repeating: "0", count: 64),
				sizeBytes: 1_500_000_000,
				minimumMacOS: OperatingSystemVersion(
					majorVersion: lane == .arm ? 26 : 15, minorVersion: 0, patchVersion: 0),
				prefixRevision: 1,
				interface: RuntimeManifest.Interface(
					archive: .init(wineDirectory: "wine", dxmtDirectory: "dxmt"),
					executables: ["Arknights.exe"],
					features: .conservative,
					requiredFiles: [],
					macDriver: "Arknights.app/Contents/MacOS/winemac.so",
					launcher: .init(path: "Arknights.app", target: "Arknights"),
					dxmt: .init(
						payloadDirectory: "dxmt",
						destinations: ["x86_64-windows": "x86_64-windows"],
						libraries: ["d3d11.dll"]
					)
				),
				components: nil,
				provenance: nil
			)
		}
	}
#endif
