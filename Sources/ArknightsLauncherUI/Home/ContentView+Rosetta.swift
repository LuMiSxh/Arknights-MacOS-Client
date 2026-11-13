// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation

extension ContentView {
	func onboardingPresentationDidChange(_ isPresented: Bool) {
		if isPresented {
			presentation.removeRosettaPreflightFailures()
			// Setup shows these failures inline; the sheet returns when setup closes.
			if model.lifecycle.state.presentation.failure?.isShownInSetup == true {
				presentation.removeFailures()
			}
		} else if let failure = model.lifecycle.state.presentation.failure {
			presentation.request(.failure(failure))
		}
	}

	func performRecoveryAction(_ action: RecoveryAction, _ failure: LauncherFailurePresentation) {
		adoptPresentedFailure(failure)
		let disposition = model.performRecoveryAction(action, failureID: failure.id)
		switch disposition {
		case .repairConfirmationRequired:
			presentation.dismissCurrent()
			repairFailureID = failure.id
			confirmation = .repair(failure.id)
		case .rosettaConfirmationRequired:
			presentation.dismissCurrent()
			confirmation = .rosetta
		case .completed:
			if action == .retry { presentation.dismissCurrent() }
		case .ignored:
			break
		}
	}

	/// The sheet can outlive a lifecycle failure cleared during a presentation swap. Its own
	/// snapshot is what its buttons act on, so restore it before the model validates the id.
	private func adoptPresentedFailure(_ failure: LauncherFailurePresentation) {
		guard model.lifecycle.state.presentation.failure?.id != failure.id else { return }
		model.lifecycle.restoreFailure(failure)
	}
}
