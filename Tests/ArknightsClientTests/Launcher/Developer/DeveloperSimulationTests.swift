// SPDX-License-Identifier: MPL-2.0

import Testing

@testable import ArknightsClient

#if DEBUG
	@Test
	func developerSimulationKeepsReadinessAndProgressIndependent() {
		var state = DeveloperSimulationState()
		state.lifecycle = .installing
		state.isInstalled = true
		state.hasPartialDownload = true
		state.progressMode = .known
		state.progressPercent = 0.42
		state.updateAvailable = true

		let projection = state.projection()

		#expect(projection.lifecycle == .installing)
		#expect(projection.status == .downloading)
		#expect(projection.isInstalled)
		#expect(projection.hasPartialDownload)
		#expect(projection.isGameUpdateAvailable)
		#expect(projection.progress?.fraction == 0.42)
	}

	@Test
	func developerSimulationCanHideProgressValuesWithoutChangingLifecycle() {
		var state = DeveloperSimulationState()
		state.lifecycle = .paused
		state.progressMode = .unknown
		state.progressPercent = 0.91

		let projection = state.projection()

		#expect(projection.lifecycle == .paused)
		#expect(projection.status == .paused)
		#expect(projection.progress == nil)
	}

	@Test
	func developerSimulationUsesKnownValuesForPartialReadyState() {
		var state = DeveloperSimulationState()
		state.lifecycle = .ready
		state.isInstalled = false
		state.hasPartialDownload = true
		state.downloadedBytes = 5
		state.totalBytes = 10

		let projection = state.projection()

		#expect(projection.status == .paused)
		#expect(projection.progress?.downloadedBytes == 5)
		#expect(projection.progress?.fraction == 0.5)
	}

	@Test
	func developerSimulationMapsLauncherAndSupportFailures() {
		var state = DeveloperSimulationState()
		state.launcherUpdate = .failed
		state.failure = .runtime
		state.failureCode = .narwhal

		let projection = state.projection()

		#expect(projection.launcherUpdateVersion == nil)
		#expect(projection.launcherUpdateStatus == "Couldn’t check for updates")
		#expect(projection.failureCode == .narwhal)
		#expect(projection.failureOperation == .runtimeExit)
	}

	@Test
	func developerSimulationUsesExistingRegionAvailabilityRules() {
		var state = DeveloperSimulationState()
		state.canaryFeaturesEnabled = true
		state.chinaClientsEnabled = true
		state.taiwanClientEnabled = false

		#expect(
			state.selectableRegions == [.global, .japan, .korea, .china, .chinaBilibili]
		)
	}

	@Test
	func developerSimulationProjectsTheSelectedInstallationPhase() {
		let expected: [(DeveloperPreviewInstallationPhase, LauncherStatus)] = [
			(.preparing, .preparingInstallation),
			(.verifying, .verifyingInstallation),
			(.downloading, .downloading),
			(.pausing, .pausing),
		]

		for (phase, status) in expected {
			var state = DeveloperSimulationState()
			state.lifecycle = .installing
			state.installationPhase = phase
			#expect(state.projection().status == status)
		}
	}

	@Test
	func developerSimulationNormalizesImpossibleFixtureCombinations() {
		var state = DeveloperSimulationState()
		state.selectedRegion = .taiwan
		state.installedRegions = [.global, .taiwan]
		state.isInstalled = false
		state.updateAvailable = true
		state.lifecycle = .paused
		state.downloadedBytes = -10
		state.totalBytes = 0
		state.completedFiles = 12
		state.totalFiles = 2
		state.currentFile = "  "
		state.transferRateBytesPerSecond = -.infinity

		let normalized = state.normalized()

		#expect(normalized.selectedRegion == .global)
		#expect(normalized.installedRegions.isEmpty)
		#expect(normalized.updateAvailable == false)
		#expect(normalized.hasPartialDownload)
		#expect(normalized.totalBytes == 1)
		#expect(normalized.downloadedBytes == 0)
		#expect(normalized.totalFiles == normalized.completedFiles)
		#expect(!normalized.currentFile.isEmpty)
		#expect(normalized.transferRateBytesPerSecond == 0)
	}

	@Test
	func developerSimulationKeepsSelectedInstallToggleAndRegionSetInSync() {
		var state = DeveloperSimulationState()
		state.selectedRegion = .japan
		state.installedRegions = [.global, .japan]
		state.isInstalled = false

		let uninstalled = state.normalized()
		#expect(!uninstalled.isInstalled)
		#expect(uninstalled.installedRegions == [.global])

		state.isInstalled = true
		state.installedRegions.remove(.japan)
		let installed = state.normalized()
		#expect(installed.isInstalled)
		#expect(installed.installedRegions == [.global, .japan])
	}

	@Test
	func developerSimulationProjectsTransferSpeedAndStalledState() {
		var state = DeveloperSimulationState()
		state.lifecycle = .installing
		state.transferRateBytesPerSecond = 4_200_000
		state.transferStalled = true

		let known = state.projection().progress
		#expect(known?.transferRateBytesPerSecond == 4_200_000)
		#expect(known?.isTransferStalled == true)

		state.transferRateMode = .unknown
		let unknown = state.projection().progress
		#expect(unknown?.transferRateBytesPerSecond == nil)
		#expect(unknown?.isTransferStalled == true)
	}
#endif
