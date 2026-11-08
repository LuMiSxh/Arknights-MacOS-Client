// SPDX-License-Identifier: MPL-2.0

import Dispatch
import Foundation
import Synchronization

package struct ChildProcessTimeout: Error, Sendable {}

struct ChildProcessNotStarted: Error, Sendable {}
struct ChildProcessAlreadyStarted: Error, Sendable {}

// Without an output pipe, cancellation and timeout resume the caller at once. With one, they only
// terminate the child; the caller resumes after the child exits and its output ends, so the child
// is reaped before the error is reported.
package final class ChildProcess: @unchecked Sendable {
	package enum Output {
		/// Writes both output streams to `handle`.
		case file(FileHandle)
		/// Captures the last `maximumBytes` of both output streams.
		case captured(maximumBytes: Int)
		/// Drains both output streams and discards them; the caller waits for the child to exit.
		case discarded
	}

	package struct Result: Sendable {
		package let status: Int32
		package let output: Data
	}

	/// A blocking wait. `result` is nil when the child did not exit after termination.
	package struct SynchronousExit: Sendable {
		package let timedOut: Bool
		package let result: Result?
	}

	private typealias Continuation = CheckedContinuation<Result, any Error>

	private struct State {
		var continuation: Continuation?
		var output = Data()
		var terminationStatus: Int32?
		var outputReachedEnd: Bool
		var hasStartRequested = false
		var hasStarted = false
		var isFinished = false
		var hasRequestedTermination = false
		var abortError: (any Error)?
		var timeoutTask: Task<Void, Never>?
		var exitSignal: DispatchSemaphore?
		var outcome: Swift.Result<Result, any Error>?
	}

	private struct Settled {
		let continuation: Continuation?
		let outcome: Swift.Result<Result, any Error>
		let timeoutTask: Task<Void, Never>?
		let exitSignal: DispatchSemaphore?
	}

	private let process = Process()
	private let outputPipe: Pipe?
	private let maximumOutputBytes: Int
	private let spawnGate: (any ProcessSpawnGating)?
	private let state: Mutex<State>

	package init(
		executable: URL,
		arguments: [String],
		environment: [String: String]? = nil,
		output: Output,
		spawnGate: (any ProcessSpawnGating)? = nil
	) {
		process.executableURL = executable
		process.arguments = arguments
		process.environment = environment
		switch output {
		case .file(let handle):
			process.standardOutput = handle
			process.standardError = handle
			outputPipe = nil
			maximumOutputBytes = 0
		case .captured(let maximumBytes):
			let pipe = Pipe()
			process.standardOutput = pipe
			process.standardError = pipe
			outputPipe = pipe
			maximumOutputBytes = maximumBytes
		case .discarded:
			let pipe = Pipe()
			process.standardOutput = pipe
			process.standardError = pipe
			outputPipe = pipe
			maximumOutputBytes = 0
		}
		self.spawnGate = spawnGate
		state = Mutex(State(outputReachedEnd: outputPipe == nil))
	}

	/// Starts the child and waits for it. Cancelling the task terminates the child.
	package func run<C: Clock>(
		timeout: Duration? = nil, clock: C = ContinuousClock()
	)
		async throws -> Result where C.Duration == Duration
	{
		try await withTaskCancellationHandler {
			try start()
			return try await wait(timeout: timeout, clock: clock)
		} onCancel: {
			abort(with: CancellationError())
		}
	}

	/// Starts the child at once. Use `wait` or `waitSynchronously` afterward.
	package func start() throws {
		let rejection = state.withLock { state -> (any Error)? in
			if let error = state.abortError { return error }
			if state.hasStartRequested { return ChildProcessAlreadyStarted() }
			state.hasStartRequested = true
			state.exitSignal = DispatchSemaphore(value: 0)
			return nil
		}
		if let rejection { throw rejection }
		installHandlers()
		do {
			try spawn()
		} catch {
			outputPipe?.fileHandleForReading.readabilityHandler = nil
			let reportedError = state.withLock { $0.abortError } ?? error
			settle { _ in .failure(reportedError) }
			throw reportedError
		}
	}

	/// Suspends until the child started by `start()` exits. Cancelling the task terminates it.
	package func wait<C: Clock>(
		timeout: Duration? = nil, clock: C = ContinuousClock()
	)
		async throws -> Result where C.Duration == Duration
	{
		try await withTaskCancellationHandler {
			try await withCheckedThrowingContinuation { continuation in
				register(continuation, timeout: timeout, clock: clock)
			}
		} onCancel: {
			abort(with: CancellationError())
		}
	}

	/// Blocks until the child started by `start()` exits, for termination paths.
	///
	/// When `timeout` elapses, terminates the child and waits `timeout` again. Returns a nil
	/// `result` when it still has not exited.
	package func waitSynchronously(timeout: Duration) throws -> SynchronousExit {
		guard let exitSignal = state.withLock({ $0.exitSignal }) else {
			throw ChildProcessNotStarted()
		}
		if let outcome = state.withLock({ $0.outcome }) {
			return SynchronousExit(timedOut: false, result: try outcome.get())
		}
		let interval = DispatchTimeInterval(duration: timeout)
		var timedOut = false
		if exitSignal.wait(timeout: .now() + interval) == .timedOut {
			timedOut = true
			requestTermination()
			guard exitSignal.wait(timeout: .now() + interval) == .success else {
				return SynchronousExit(timedOut: true, result: nil)
			}
		}
		let outcome = state.withLock { $0.outcome }
		return SynchronousExit(timedOut: timedOut, result: try outcome?.get())
	}

	private func register<C: Clock>(
		_ continuation: Continuation, timeout: Duration?, clock: C
	) where C.Duration == Duration {
		let immediate = state.withLock { state -> Swift.Result<Result, any Error>? in
			if let outcome = state.outcome { return outcome }
			if state.abortError == nil, !state.hasStarted {
				return .failure(ChildProcessNotStarted())
			}
			state.continuation = continuation
			if let timeout {
				state.timeoutTask = Task { [weak self] in
					do {
						try await clock.sleep(for: timeout)
					} catch {
						return
					}
					self?.abort(with: ChildProcessTimeout())
				}
			}
			return nil
		}
		if let immediate { continuation.resume(with: immediate) }
	}

	// The handler must be installed before the spawn gate wraps `terminationHandler`. Setting one
	// after the gate would replace its wrapper and the child would never retire.
	private func installHandlers() {
		process.terminationHandler = { [weak self] process in
			self?.state.withLock { $0.terminationStatus = process.terminationStatus }
			self?.completeIfReady()
		}
		outputPipe?.fileHandleForReading.readabilityHandler = { [weak self] handle in
			self?.readAvailableData(from: handle)
		}
	}

	private func spawn() throws {
		let operation = {
			try self.state.withLock { state in
				if let error = state.abortError { throw error }
				try self.process.run()
				state.hasStarted = true
			}
		}
		if let spawnGate {
			try spawnGate.runIfAllowed(process: process, operation)
		} else {
			try operation()
		}
	}

	private func abort(with error: any Error) {
		let shouldTerminate = state.withLock { state -> Bool in
			if state.abortError == nil { state.abortError = error }
			guard state.hasStarted, !state.isFinished, !state.hasRequestedTermination else {
				return false
			}
			state.hasRequestedTermination = true
			return true
		}
		if shouldTerminate { process.terminate() }
		if outputPipe == nil { settle { _ in .failure(error) } }
	}

	private func requestTermination() {
		let shouldTerminate = state.withLock { state -> Bool in
			guard state.hasStarted, !state.isFinished, !state.hasRequestedTermination else {
				return false
			}
			state.hasRequestedTermination = true
			return true
		}
		if shouldTerminate { process.terminate() }
	}

	private func readAvailableData(from handle: FileHandle) {
		let data = handle.availableData
		guard !data.isEmpty else {
			handle.readabilityHandler = nil
			state.withLock { $0.outputReachedEnd = true }
			completeIfReady()
			return
		}
		guard maximumOutputBytes > 0 else { return }
		state.withLock { state in
			if data.count >= maximumOutputBytes {
				state.output = Data(data.suffix(maximumOutputBytes))
				return
			}
			let overflow = state.output.count + data.count - maximumOutputBytes
			if overflow > 0 { state.output.removeFirst(overflow) }
			state.output.append(data)
		}
	}

	private func completeIfReady() {
		settle { state in
			guard state.outputReachedEnd, let status = state.terminationStatus else { return nil }
			if let error = state.abortError { return .failure(error) }
			return .success(Result(status: status, output: state.output))
		}
	}

	// Resumes the waiter once, with the first outcome `decide` accepts. Records the outcome even
	// without a waiter, so a blocking wait can read it.
	private func settle(_ decide: (State) -> Swift.Result<Result, any Error>?) {
		let settled = state.withLock { state -> Settled? in
			guard !state.isFinished, let outcome = decide(state) else { return nil }
			state.isFinished = true
			state.outcome = outcome
			let settled = Settled(
				continuation: state.continuation,
				outcome: outcome,
				timeoutTask: state.timeoutTask,
				exitSignal: state.exitSignal
			)
			state.continuation = nil
			state.timeoutTask = nil
			return settled
		}
		guard let settled else { return }
		settled.timeoutTask?.cancel()
		settled.exitSignal?.signal()
		settled.continuation?.resume(with: settled.outcome)
	}
}
