// SPDX-License-Identifier: MPL-2.0

import Dispatch
import Foundation
import Synchronization

struct ChildProcessTimeout: Error, Sendable {}

/// Owns one short-lived child process and resumes its awaiting task exactly once.
///
/// Without captured output, cancellation and timeout resume the caller at once. With captured
/// output, they only terminate the child; the caller resumes after the child exits and its output
/// ends, so the child is reaped before the error is reported.
final class ChildProcess: @unchecked Sendable {
	enum Output {
		case file(FileHandle)
		/// Drains output while the child runs and keeps the last `maximumBytes`.
		case captured(maximumBytes: Int)
	}

	struct Result: Sendable {
		let status: Int32
		let output: Data
	}

	private typealias Continuation = CheckedContinuation<Result, any Error>

	private struct State {
		var continuation: Continuation?
		var output = Data()
		var terminationStatus: Int32?
		var outputReachedEnd: Bool
		var hasStarted = false
		var isFinished = false
		var hasRequestedTermination = false
		var abortError: (any Error)?
		var timer: DispatchSourceTimer?
	}

	private let process = Process()
	private let outputPipe: Pipe?
	private let maximumOutputBytes: Int
	private let spawnGate: WineProcessSpawnGate?
	private let state: Mutex<State>

	init(
		executable: URL,
		arguments: [String],
		environment: [String: String]? = nil,
		output: Output,
		spawnGate: WineProcessSpawnGate? = nil
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
		}
		self.spawnGate = spawnGate
		state = Mutex(State(outputReachedEnd: outputPipe == nil))
	}

	func run(timeout: Duration? = nil) async throws -> Result {
		try await withTaskCancellationHandler {
			try await withCheckedThrowingContinuation { start($0, timeout: timeout) }
		} onCancel: {
			abort(with: CancellationError())
		}
	}

	private func start(_ continuation: Continuation, timeout: Duration?) {
		let rejection = state.withLock { state -> (any Error)? in
			if let error = state.abortError { return error }
			state.continuation = continuation
			if let timeout {
				let timer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
				timer.schedule(deadline: .now() + Self.dispatchInterval(for: timeout))
				timer.setEventHandler { [weak self] in
					self?.abort(with: ChildProcessTimeout())
				}
				state.timer = timer
				timer.resume()
			}
			return nil
		}
		if let rejection {
			continuation.resume(throwing: rejection)
			return
		}

		process.terminationHandler = { [weak self] process in
			self?.state.withLock { $0.terminationStatus = process.terminationStatus }
			self?.completeIfReady()
		}
		outputPipe?.fileHandleForReading.readabilityHandler = { [weak self] handle in
			self?.readAvailableData(from: handle)
		}

		do {
			let spawn = {
				try self.state.withLock { state in
					if let error = state.abortError { throw error }
					try self.process.run()
					state.hasStarted = true
				}
			}
			if let spawnGate {
				try spawnGate.runIfAllowed(process: process, spawn)
			} else {
				try spawn()
			}
		} catch {
			outputPipe?.fileHandleForReading.readabilityHandler = nil
			let reportedError = state.withLock { $0.abortError } ?? error
			settle { _ in .failure(reportedError) }
		}
	}

	private func abort(with error: any Error) {
		let shouldTerminate = state.withLock { state in
			if state.abortError == nil { state.abortError = error }
			let shouldTerminate =
				state.hasStarted && !state.isFinished && !state.hasRequestedTermination
			if shouldTerminate { state.hasRequestedTermination = true }
			return shouldTerminate
		}
		if shouldTerminate, process.isRunning { process.terminate() }
		if outputPipe == nil { settle { _ in .failure(error) } }
	}

	private func readAvailableData(from handle: FileHandle) {
		let data = handle.availableData
		guard !data.isEmpty else {
			handle.readabilityHandler = nil
			state.withLock { $0.outputReachedEnd = true }
			completeIfReady()
			return
		}
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

	/// Resumes the awaiting task once, with the first outcome `decide` accepts.
	private func settle(_ decide: (State) -> Swift.Result<Result, any Error>?) {
		let settled = state.withLock {
			state -> (Continuation, Swift.Result<Result, any Error>, DispatchSourceTimer?)? in
			guard !state.isFinished, let continuation = state.continuation,
				let outcome = decide(state)
			else { return nil }
			state.isFinished = true
			state.continuation = nil
			let timer = state.timer
			state.timer = nil
			return (continuation, outcome, timer)
		}
		guard let (continuation, outcome, timer) = settled else { return }
		timer?.cancel()
		continuation.resume(with: outcome)
	}

	private static func dispatchInterval(for duration: Duration) -> DispatchTimeInterval {
		let components = duration.components
		let seconds = Double(components.seconds)
		let fractionalSeconds = Double(components.attoseconds) / 1_000_000_000_000_000_000
		let nanoseconds = Int(max(0, seconds + fractionalSeconds) * 1_000_000_000)
		return .nanoseconds(nanoseconds)
	}
}
