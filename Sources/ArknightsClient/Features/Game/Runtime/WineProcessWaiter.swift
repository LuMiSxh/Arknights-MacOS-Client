// SPDX-License-Identifier: MPL-2.0

import Foundation

/// Owns one short-lived Wine helper process and resumes its awaiting task exactly once.
final class WineProcessWaiter: @unchecked Sendable {
	private let lock = NSLock()
	private var process: Process?
	private var continuation: CheckedContinuation<Int32, any Error>?
	private var hasStarted = false
	private var isCancelled = false
	private var isFinished = false

	init(
		executable: URL,
		arguments: [String],
		environment: [String: String],
		output: FileHandle
	) {
		let process = Process()
		process.executableURL = executable
		process.arguments = arguments
		process.environment = environment
		process.standardOutput = output
		process.standardError = output
		self.process = process
	}

	func wait() async throws -> Int32 {
		try await withTaskCancellationHandler {
			try await withCheckedThrowingContinuation { continuation in
				start(continuation)
			}
		} onCancel: {
			cancel()
		}
	}

	private func start(_ continuation: CheckedContinuation<Int32, any Error>) {
		lock.lock()
		if isCancelled || isFinished {
			isFinished = true
			lock.unlock()
			continuation.resume(throwing: CancellationError())
			return
		}
		self.continuation = continuation
		let process = process
		lock.unlock()

		guard let process else {
			finish(error: CancellationError())
			return
		}
		process.terminationHandler = { [weak self] process in
			self?.finish(status: process.terminationStatus)
		}

		lock.lock()
		let shouldRun = !isCancelled && !isFinished
		lock.unlock()
		guard shouldRun else {
			finish(error: CancellationError())
			return
		}

		do {
			try process.run()
		} catch {
			lock.lock()
			let cancelled = isCancelled
			lock.unlock()
			finish(error: cancelled ? CancellationError() : error)
			return
		}

		lock.lock()
		hasStarted = true
		let cancelledAfterStart = isCancelled
		lock.unlock()
		if cancelledAfterStart { cancel() }
	}

	private func cancel() {
		lock.lock()
		isCancelled = true
		guard hasStarted, !isFinished, let process, let continuation else {
			lock.unlock()
			return
		}
		isFinished = true
		self.process = nil
		self.continuation = nil
		lock.unlock()

		process.terminate()
		continuation.resume(throwing: CancellationError())
	}

	private func finish(status: Int32) {
		lock.lock()
		guard !isFinished, let continuation else {
			lock.unlock()
			return
		}
		isFinished = true
		process = nil
		self.continuation = nil
		lock.unlock()
		continuation.resume(returning: status)
	}

	private func finish(error: any Error) {
		lock.lock()
		guard !isFinished, let continuation else {
			lock.unlock()
			return
		}
		isFinished = true
		process = nil
		self.continuation = nil
		lock.unlock()
		continuation.resume(throwing: error)
	}
}
