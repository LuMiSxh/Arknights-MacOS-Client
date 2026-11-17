// SPDX-License-Identifier: MPL-2.0

import Testing

@testable import ArknightsCustomization

struct PresetImageFetchLimiterTests {
	private actor Recorder {
		private(set) var entries: [String] = []
		func add(_ entry: String) { entries.append(entry) }
	}

	private func waitUntil(_ condition: () async -> Bool) async {
		while !(await condition()) { await Task.yield() }
	}

	@Test
	func boundsConcurrencyAndServesInteractiveRequestsFirst() async throws {
		let limiter = PresetImageFetchLimiter(limit: 2)
		let recorder = Recorder()
		try await limiter.acquire(priority: .background)
		try await limiter.acquire(priority: .background)

		var tasks: [Task<Void, any Error>] = []
		for (index, (name, priority)) in [
			("background-1", PresetImageFetchLimiter.Priority.background),
			("background-2", .background),
			("interactive", .interactive),
		].enumerated() {
			tasks.append(
				Task {
					try await limiter.acquire(priority: priority)
					await recorder.add(name)
				})
			await waitUntil { await limiter.waitingCount == index + 1 }
		}
		#expect(await limiter.activeCount == 2)

		for (step, expected) in ["interactive", "background-1", "background-2"].enumerated() {
			await limiter.release()
			await waitUntil { await recorder.entries.count == step + 1 }
			#expect(await recorder.entries.last == expected)
			#expect(await limiter.activeCount == 2)
		}
		for task in tasks { try await task.value }
	}

	@Test
	func cancellingAQueuedRequestFreesItsPlace() async throws {
		let limiter = PresetImageFetchLimiter(limit: 1)
		try await limiter.acquire(priority: .background)
		let queued = Task { try await limiter.acquire(priority: .background) }
		await waitUntil { await limiter.waitingCount == 1 }

		queued.cancel()
		await #expect(throws: CancellationError.self) { try await queued.value }
		#expect(await limiter.waitingCount == 0)

		await limiter.release()
		try await limiter.acquire(priority: .background)
		#expect(await limiter.activeCount == 1)
	}

	@Test
	func aFailingOperationReleasesItsSlot() async throws {
		struct Failure: Error {}
		let limiter = PresetImageFetchLimiter(limit: 1)
		await #expect(throws: Failure.self) {
			try await limiter.run(priority: .background) { throw Failure() }
		}
		#expect(await limiter.activeCount == 0)
	}
}
