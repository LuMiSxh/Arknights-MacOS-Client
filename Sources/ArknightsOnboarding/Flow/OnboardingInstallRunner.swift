// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameRuntime
import Foundation
import Observation

/// Starts the setup runtime install at most once at a time. The in-flight flag is set before the
/// first suspension, so a second press during the same turn is a no-op. The coordinator owns the
/// runner, so the work outlives step navigation and view rebuilds.
@MainActor
@Observable
final class OnboardingInstallRunner {
	private let slot = TaskSlot()

	private(set) var isRunning = false

	/// Returns false when a runtime install is already running.
	@discardableResult
	func installRuntime(
		_ lane: RuntimeLane,
		startsGameDownload: Bool,
		actions: OnboardingActions
	) -> Bool {
		guard !isRunning else { return false }
		isRunning = true
		if startsGameDownload { actions.installOrUpdate() }
		slot.replace { [self] token in
			_ = await actions.installRuntime(lane)
			guard slot.owns(token) else { return }
			isRunning = false
		}
		return true
	}
}
