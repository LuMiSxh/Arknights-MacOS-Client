// SPDX-License-Identifier: MPL-2.0

@testable import ArknightsClient

actor TranslationCheckSequence {
	private var states: [IntelTranslationState]
	private(set) var count = 0

	init(states: [IntelTranslationState]) {
		self.states = states
	}

	func next() -> IntelTranslationCheck {
		count += 1
		let state = states.isEmpty ? .unavailable : states.removeFirst()
		return IntelTranslationCheck(state: state, diagnostics: "test-\(count)")
	}
}

actor RosettaInstallationRecorder {
	private let status: Int32
	private(set) var count = 0
	private var waiters: [(Int, CheckedContinuation<Void, Never>)] = []

	init(status: Int32) {
		self.status = status
	}

	func install() -> IntelTranslationProcessResult {
		count += 1
		let ready = waiters.filter { $0.0 <= count }
		waiters.removeAll { $0.0 <= count }
		for (_, continuation) in ready { continuation.resume() }
		return IntelTranslationProcessResult(status: status, output: "test")
	}

	func waitForInstallations(_ expected: Int) async {
		guard count < expected else { return }
		await withCheckedContinuation { waiters.append((expected, $0)) }
	}
}
