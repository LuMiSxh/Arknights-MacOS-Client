// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameRuntime
import Foundation
import Testing

@testable import ArknightsOnboarding

@MainActor
struct OnboardingInstallRunnerTests {
	@MainActor
	private final class Recorder {
		var gameStarts = 0
		var runtimeInstalls = 0
		var continuation: CheckedContinuation<Bool, Never>?
	}

	private func makeActions(_ recorder: Recorder) -> OnboardingActions {
		OnboardingActions(
			selectRegion: { _ in },
			resetArtwork: {},
			installOrUpdate: { recorder.gameStarts += 1 },
			pauseDownload: {},
			chooseInstallDirectory: {},
			locateExistingInstallation: {},
			installRuntime: { _ in
				recorder.runtimeInstalls += 1
				return await withCheckedContinuation { recorder.continuation = $0 }
			},
			pauseRuntime: {},
			selectRuntimeLane: { _ in true },
			openLauncherUpdate: {},
			retryIntelTranslation: { .available },
			installRosetta: { .available }
		)
	}

	@Test
	func rapidTriggersStartTheInstallOnce() async {
		let recorder = Recorder()
		let actions = makeActions(recorder)
		let runner = OnboardingInstallRunner()
		var advances = 0

		let first = runner.installRuntime(
			.arm, startsGameDownload: true, actions: actions, whenInstalled: { advances += 1 })
		let second = runner.installRuntime(
			.arm, startsGameDownload: true, actions: actions, whenInstalled: { advances += 1 })
		#expect(first)
		#expect(!second)
		#expect(runner.isRunning)

		while recorder.continuation == nil { await Task.yield() }
		recorder.continuation?.resume(returning: true)
		while runner.isRunning { await Task.yield() }

		#expect(recorder.gameStarts == 1)
		#expect(recorder.runtimeInstalls == 1)
		#expect(advances == 1)
	}
}
