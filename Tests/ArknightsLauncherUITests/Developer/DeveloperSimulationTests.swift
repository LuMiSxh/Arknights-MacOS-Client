// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Testing

@testable import ArknightsLauncherUI

#if DEBUG
	@MainActor
	struct DeveloperSimulationTests {
		@Test
		func readinessAndProgressStayIndependent() {
			var state = DeveloperSimulationState()
			state.lifecycle = .installing
			state.hasPartialDownload = true
			state.updateAvailable = true

			#expect(state.status == .downloading)
			#expect(state.isInstalled)
			#expect(state.downloadProgress?.fraction == 0.42)

			state.progress = .unknown
			#expect(state.downloadProgress == nil)
			#expect(state.status == .downloading)
		}

		@Test
		func verificationUsesTheRealVerificationPresentation() throws {
			var state = DeveloperSimulationState()
			state.lifecycle = .installing
			state.phase = .verifying
			state.transfer = .stalled

			let progress = try #require(state.downloadProgress)
			#expect(progress.isVerifying)
			#expect(progress.transferRateBytesPerSecond == nil)
			#expect(!progress.isTransferStalled)
			#expect(
				LauncherDownloadProgressPresentation.title(for: progress, isPaused: false)
					== "Verifying · 42%"
			)
			state.lifecycle = .paused
			#expect(state.downloadProgress == nil)
		}

		@Test
		func partialReadyStateShowsKnownProgress() {
			var state = DeveloperSimulationState()
			state.isInstalled = false
			state.hasPartialDownload = true

			#expect(state.status == .paused)
			#expect(state.downloadProgress != nil)
		}

		@Test
		func normalizingRemovesImpossibleCombinations() {
			var state = DeveloperSimulationState()
			state.selectedRegion = .taiwan
			state.installedRegions = [.global, .taiwan]
			state.updateAvailable = true
			state.lifecycle = .paused
			state.isInstalled = false

			let paused = state.normalized()
			#expect(paused.selectedRegion == .global)
			#expect(paused.installedRegions == [.global])
			#expect(paused.hasPartialDownload)

			state.lifecycle = .running
			state.hasPartialDownload = true
			let running = state.normalized()
			#expect(running.isInstalled)
			#expect(!running.hasPartialDownload)
			#expect(!running.updateAvailable)
		}
	}
#endif
