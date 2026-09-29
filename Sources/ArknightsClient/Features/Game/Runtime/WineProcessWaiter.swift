// SPDX-License-Identifier: MPL-2.0

import Darwin
import Dispatch
import Foundation

struct WineProcessWaitTimeout: Error, Sendable {}

/// Owns one short-lived Wine helper process and resumes its awaiting task exactly once.
final class WineProcessWaiter: @unchecked Sendable {
	private let lock = NSLock()
	private var process: Process?
	private var continuation: CheckedContinuation<Int32, any Error>?
	private var hasStarted = false
	private var isCancelled = false
	private var isFinished = false
	private var cancellationError: (any Error)?
	private var timeoutTimer: DispatchSourceTimer?
	private let spawnGate: WineProcessSpawnGate?
	private let terminationGracePeriod: Duration

	init(
		executable: URL,
		arguments: [String],
		environment: [String: String],
		output: FileHandle,
		spawnGate: WineProcessSpawnGate? = nil,
		terminationGracePeriod: Duration = .seconds(
			AppConstants.Timeouts.processTerminateGracePeriod
		)
	) {
		let process = Process()
		process.executableURL = executable
		process.arguments = arguments
		process.environment = environment
		process.standardOutput = output
		process.standardError = output
		self.process = process
		self.spawnGate = spawnGate
		self.terminationGracePeriod = terminationGracePeriod
	}

	func wait(timeout: Duration? = nil) async throws -> Int32 {
		try await withTaskCancellationHandler {
			try await withCheckedThrowingContinuation { continuation in
				start(continuation, timeout: timeout)
			}
		} onCancel: {
			cancel(with: CancellationError())
		}
	}

	private func start(
		_ continuation: CheckedContinuation<Int32, any Error>,
		timeout: Duration?
	) {
		lock.lock()
		if isCancelled || isFinished {
			isFinished = true
			process = nil
			let error = cancellationError ?? CancellationError()
			lock.unlock()
			continuation.resume(throwing: error)
			return
		}
		self.continuation = continuation
		let process = process
		if let timeout {
			let timer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
			timer.schedule(deadline: .now() + Self.dispatchInterval(for: timeout))
			timer.setEventHandler { [weak self] in
				self?.cancel(with: WineProcessWaitTimeout())
			}
			timeoutTimer = timer
			timer.resume()
		}
		lock.unlock()

		guard let process else {
			finish(error: CancellationError())
			return
		}
		process.terminationHandler = { [weak self] process in
			self?.finish(status: process.terminationStatus)
		}

		do {
			let run = {
				self.lock.lock()
				defer { self.lock.unlock() }
				guard !self.isCancelled, !self.isFinished else {
					throw self.cancellationError ?? CancellationError()
				}
				try process.run()
				self.hasStarted = true
			}
			if let spawnGate {
				try spawnGate.runIfAllowed(run)
			} else {
				try run()
			}
		} catch {
			lock.lock()
			let cancellationError = self.cancellationError
			lock.unlock()
			finish(error: cancellationError ?? error)
			return
		}

	}

	private func cancel(with error: any Error) {
		lock.lock()
		isCancelled = true
		cancellationError = error
		guard !isFinished, let continuation else {
			lock.unlock()
			return
		}
		isFinished = true
		let process = hasStarted ? self.process : nil
		if hasStarted { self.process = nil }
		self.continuation = nil
		let timer = takeTimeoutTimer()
		lock.unlock()

		timer?.cancel()
		if let process {
			process.terminate()
			let processIdentifier = process.processIdentifier
			DispatchQueue.global(qos: .utility).asyncAfter(
				deadline: .now() + Self.dispatchInterval(for: terminationGracePeriod)
			) {
				guard process.isRunning,
					Darwin.kill(processIdentifier, 0) == 0
				else { return }
				_ = Darwin.kill(processIdentifier, SIGKILL)
			}
		}
		continuation.resume(throwing: error)
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
		let timer = takeTimeoutTimer()
		lock.unlock()
		timer?.cancel()
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
		let timer = takeTimeoutTimer()
		lock.unlock()
		timer?.cancel()
		continuation.resume(throwing: error)
	}

	private func takeTimeoutTimer() -> DispatchSourceTimer? {
		defer { timeoutTimer = nil }
		return timeoutTimer
	}

	private static func dispatchInterval(for duration: Duration) -> DispatchTimeInterval {
		let components = duration.components
		let seconds = Double(components.seconds)
		let fractionalSeconds = Double(components.attoseconds) / 1_000_000_000_000_000_000
		let nanoseconds = Int(max(0, seconds + fractionalSeconds) * 1_000_000_000)
		return .nanoseconds(nanoseconds)
	}
}
