// SPDX-License-Identifier: MPL-2.0

import ArknightsTestSupport
import Testing

@testable import ArknightsCore

@MainActor
struct TaskSlotTests {
	@Test
	func replacingOrInvalidatingMakesEarlierTokensStale() {
		let slot = TaskSlot()
		let first = slot.begin()
		#expect(slot.owns(first))

		let second = slot.begin()
		#expect(!slot.owns(first))
		#expect(slot.owns(second))

		slot.invalidate()
		#expect(!slot.owns(second))
	}

	@Test(.timeLimit(.minutes(1)))
	func replaceCancelsThePreviousTask() async {
		let slot = TaskSlot()
		let first = slot.replace { _ in
			// Never fired: `wait()` returns only when the slot cancels this task.
			await Signal().wait()
		}
		let second = slot.replace { _ in }
		await first.value
		await second.value
		#expect(first.isCancelled)
	}
}
