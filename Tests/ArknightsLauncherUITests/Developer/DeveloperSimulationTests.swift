// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Testing

@testable import ArknightsLauncherUI

#if DEBUG
	@MainActor
	struct DeveloperSimulationTests {
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
