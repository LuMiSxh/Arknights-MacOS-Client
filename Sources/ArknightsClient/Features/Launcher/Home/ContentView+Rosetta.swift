// SPDX-License-Identifier: MPL-2.0

import Foundation

extension ContentView {
	func onboardingPresentationDidChange(_ isPresented: Bool) {
		if isPresented {
			presentation.removeRosettaPreflightFailures()
		} else if let failure = model.lifecycle.failure {
			presentation.request(.failure(failure))
		}
	}

	func performRecoveryAction(_ action: RecoveryAction, _ failureID: UUID) {
		let disposition = model.performRecoveryAction(action, failureID: failureID)
		switch disposition {
		case .repairConfirmationRequired:
			presentation.dismissCurrent()
			repairFailureID = failureID
			confirmation = .repair(failureID)
		case .rosettaConfirmationRequired:
			presentation.dismissCurrent()
			confirmation = .rosetta
		case .completed:
			if action == .retry { presentation.dismissCurrent() }
		case .ignored:
			break
		}
	}
}
