// SPDX-License-Identifier: MPL-2.0

import Foundation

extension LauncherViewModel {
	func startResetCountdownTimer() {
		resetCountdownTask?.cancel()
		resetCountdownTask = Task { [weak self] in
			while !Task.isCancelled {
				guard let self else { return }
				resetCountdownText = ServerReset.countdownText(for: region)
				try? await Task.sleep(for: AppConstants.Timeouts.resetCountdownPollInterval)
			}
		}
	}

	func stopResetCountdownTimer() {
		resetCountdownTask?.cancel()
		resetCountdownTask = nil
		resetCountdownText = nil
	}
}
