// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameRuntime

package actor TranslationCheckSequence {
	private var states: [IntelTranslationState]
	package private(set) var count = 0

	package init(states: [IntelTranslationState]) {
		self.states = states
	}

	package func next() -> IntelTranslationCheck {
		count += 1
		let state = states.isEmpty ? .unavailable : states.removeFirst()
		return IntelTranslationCheck(state: state, diagnostics: "test-\(count)")
	}
}

package actor RosettaInstallationRecorder {
	private let status: Int32
	package private(set) var count = 0
	private var waiters: [(Int, CheckedContinuation<Void, Never>)] = []

	package init(status: Int32) {
		self.status = status
	}

	package func install() -> IntelTranslationProcessResult {
		count += 1
		let ready = waiters.filter { $0.0 <= count }
		waiters.removeAll { $0.0 <= count }
		for (_, continuation) in ready { continuation.resume() }
		return IntelTranslationProcessResult(status: status, output: "test")
	}

	package func waitForInstallations(_ expected: Int) async {
		guard count < expected else { return }
		await withCheckedContinuation { waiters.append((expected, $0)) }
	}
}
