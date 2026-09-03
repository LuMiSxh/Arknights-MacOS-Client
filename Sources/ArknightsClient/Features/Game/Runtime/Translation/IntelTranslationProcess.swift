// SPDX-License-Identifier: MPL-2.0

import Foundation

struct IntelTranslationProcessResult: Equatable, Sendable {
	let status: Int32
	let output: String
}

enum IntelTranslationProcess {
	static func run(
		executable: URL,
		arguments: [String]
	) async throws -> IntelTranslationProcessResult {
		try await IntelTranslationProcessWaiter(
			executable: executable,
			arguments: arguments,
			maximumOutputBytes: AppConstants.IO.processDiagnosticMaximumBytes
		).wait()
	}
}

/// Owns one translation helper, drains its output while it runs, and completes exactly once.
private final class IntelTranslationProcessWaiter: @unchecked Sendable {
	private static let cancellationWrapper = """
		child=
		cancelled=0
		terminate_child() {
			cancelled=1
			if [ -z "$child" ]; then return; fi
			trap - TERM INT
			kill -KILL "$child" 2>/dev/null
			wait "$child" 2>/dev/null
			exit 143
		}
		trap terminate_child TERM INT
		"$@" &
		child=$!
		if [ "$cancelled" -eq 1 ]; then terminate_child; fi
		wait "$child"
		status=$?
		trap - TERM INT
		exit "$status"
		"""

	private let lock = NSLock()
	private let process: Process
	private let outputPipe = Pipe()
	private let maximumOutputBytes: Int
	private var continuation: CheckedContinuation<IntelTranslationProcessResult, any Error>?
	private var output = Data()
	private var terminationStatus: Int32?
	private var hasStarted = false
	private var isCancelled = false
	private var isFinished = false
	private var hasRequestedTermination = false
	private var outputReachedEnd = false

	init(executable: URL, arguments: [String], maximumOutputBytes: Int) {
		process = Process()
		process.executableURL = URL(filePath: "/bin/sh")
		process.arguments =
			[
				"-c", Self.cancellationWrapper, "intel-translation-helper", executable.path,
			] + arguments
		process.standardOutput = outputPipe
		process.standardError = outputPipe
		self.maximumOutputBytes = maximumOutputBytes
		outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
			self?.readAvailableData(from: handle)
		}
	}

	func wait() async throws -> IntelTranslationProcessResult {
		try await withTaskCancellationHandler {
			try await withCheckedThrowingContinuation(start)
		} onCancel: {
			cancel()
		}
	}

	private func start(
		_ continuation: CheckedContinuation<IntelTranslationProcessResult, any Error>
	) {
		lock.lock()
		guard !isCancelled, !isFinished else {
			isFinished = true
			lock.unlock()
			continuation.resume(throwing: CancellationError())
			return
		}
		self.continuation = continuation
		process.terminationHandler = { [weak self] process in
			self?.processDidTerminate(status: process.terminationStatus)
		}
		do {
			try process.run()
			hasStarted = true
			let shouldCancel = isCancelled
			lock.unlock()
			if shouldCancel { requestTerminationIfNeeded() }
		} catch {
			let reportedError: any Error = isCancelled ? CancellationError() : error
			isFinished = true
			self.continuation = nil
			lock.unlock()
			stopDraining()
			continuation.resume(throwing: reportedError)
		}
	}

	private func cancel() {
		lock.lock()
		isCancelled = true
		let shouldTerminate = hasStarted && !isFinished
		lock.unlock()
		if shouldTerminate { requestTerminationIfNeeded() }
	}

	private func requestTerminationIfNeeded() {
		lock.lock()
		guard !isFinished, !hasRequestedTermination else {
			lock.unlock()
			return
		}
		hasRequestedTermination = true
		lock.unlock()

		if process.isRunning { process.terminate() }
	}

	private func processDidTerminate(status: Int32) {
		lock.withLock { terminationStatus = status }
		completeIfReady()
	}

	private func readAvailableData(from handle: FileHandle) {
		let data = handle.availableData
		guard !data.isEmpty else {
			handle.readabilityHandler = nil
			lock.withLock { outputReachedEnd = true }
			completeIfReady()
			return
		}
		append(data)
	}

	private func completeIfReady() {
		lock.lock()
		guard !isFinished, outputReachedEnd, let terminationStatus, let continuation else {
			lock.unlock()
			return
		}
		isFinished = true
		self.continuation = nil
		let captured = output
		let cancelled = isCancelled
		lock.unlock()

		if cancelled {
			continuation.resume(throwing: CancellationError())
		} else {
			continuation.resume(
				returning: IntelTranslationProcessResult(
					status: terminationStatus,
					output: String(decoding: captured, as: UTF8.self)
				)
			)
		}
	}

	private func append(_ data: Data) {
		lock.withLock {
			if data.count >= maximumOutputBytes {
				output = Data(data.suffix(maximumOutputBytes))
				return
			}
			let overflow = output.count + data.count - maximumOutputBytes
			if overflow > 0 { output.removeFirst(overflow) }
			output.append(data)
		}
	}

	private func stopDraining() {
		outputPipe.fileHandleForReading.readabilityHandler = nil
	}
}
