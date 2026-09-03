// SPDX-License-Identifier: MPL-2.0

import Foundation

actor ControlledRequestGate<Value: Sendable, Payload: Sendable> {
	private struct Request {
		let id: Int
		let payload: Payload
		let continuation: CheckedContinuation<Value, any Error>
	}

	private var requests: [Request?] = []
	private var nextID = 0
	private var cancelledIDs: Set<Int> = []

	func next(_ payload: Payload) async throws -> Value {
		let id = nextID
		nextID += 1
		return try await withTaskCancellationHandler {
			try await withCheckedThrowingContinuation {
				(continuation: CheckedContinuation<Value, any Error>) in
				if cancelledIDs.remove(id) != nil {
					continuation.resume(throwing: CancellationError())
				} else {
					requests.append(Request(id: id, payload: payload, continuation: continuation))
				}
			}
		} onCancel: {
			Task { await self.cancel(id: id) }
		}
	}

	func waitForRequestCount(_ count: Int) async {
		while requests.count < count { await Task.yield() }
	}

	func payload(at index: Int) -> Payload? {
		guard requests.indices.contains(index) else { return nil }
		return requests[index]?.payload
	}

	func resolve(_ index: Int, with value: Value) {
		guard requests.indices.contains(index), let request = requests[index] else { return }
		requests[index] = nil
		request.continuation.resume(returning: value)
	}

	private func cancel(id: Int) {
		guard let index = requests.firstIndex(where: { $0?.id == id }),
			let request = requests[index]
		else {
			cancelledIDs.insert(id)
			return
		}
		requests[index] = nil
		request.continuation.resume(throwing: CancellationError())
	}
}

extension ControlledRequestGate where Value == Void, Payload == (Data, URL) {
	func resolveStaged(_ index: Int) async throws {
		guard let (data, url) = payload(at: index) else { return }
		try FileManager.default.createDirectory(
			at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
		try data.write(to: url, options: .atomic)
		resolve(index, with: ())
	}
}
