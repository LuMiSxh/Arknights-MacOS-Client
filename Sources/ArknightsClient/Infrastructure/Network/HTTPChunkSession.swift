// SPDX-License-Identifier: MPL-2.0

import Foundation

enum HTTPTransportError: Error, Sendable {
	case invalidResponse(URL?)
	case responseTooLarge(URL, maximumBytes: Int)
	case redirectRejected(URL)
}

enum HTTPChunkEvent: Sendable {
	case response(HTTPURLResponse)
	case data(Data)
}

struct HTTPChunkStream: Sendable {
	let events: AsyncThrowingStream<HTTPChunkEvent, any Error>
	private let cancelHandler: @Sendable () -> Void

	init(
		events: AsyncThrowingStream<HTTPChunkEvent, any Error>,
		cancelHandler: @escaping @Sendable () -> Void
	) {
		self.events = events
		self.cancelHandler = cancelHandler
	}

	func cancel() {
		cancelHandler()
	}
}

/// Bridges `URLSessionDataDelegate`'s callback-based streaming into an `AsyncThrowingStream`
/// per request, so callers can process each chunk as it arrives instead of buffering a whole
/// response in memory.
final class HTTPChunkSession: NSObject, URLSessionDataDelegate, @unchecked Sendable {
	private typealias Continuation = AsyncThrowingStream<HTTPChunkEvent, any Error>.Continuation

	private let redirectValidator: (@Sendable (URL) -> Bool)?
	private let delegateQueue: OperationQueue
	private let lock = NSLock()
	private var continuations: [Int: Continuation] = [:]
	private var session: URLSession!

	init(
		configuration: URLSessionConfiguration,
		redirectValidator: (@Sendable (URL) -> Bool)? = nil
	) {
		self.redirectValidator = redirectValidator
		delegateQueue = OperationQueue()
		delegateQueue.maxConcurrentOperationCount = 1
		delegateQueue.qualityOfService = .userInitiated
		super.init()
		// `stream(for:)` is called concurrently by the installer. Create the session before
		// exposing this instance so those calls never race a lazy property's initialization.
		session = URLSession(
			configuration: configuration,
			delegate: self,
			delegateQueue: delegateQueue
		)
	}

	func stream(for request: URLRequest) -> HTTPChunkStream {
		let (events, continuation) = AsyncThrowingStream<HTTPChunkEvent, any Error>.makeStream()
		let task = session.dataTask(with: request)
		lock.withLock { continuations[task.taskIdentifier] = continuation }
		continuation.onTermination = { @Sendable [weak self, weak task] _ in
			task?.cancel()
			self?.removeContinuation(for: task?.taskIdentifier)
		}
		task.resume()
		return HTTPChunkStream(events: events) { task.cancel() }
	}

	func urlSession(
		_ session: URLSession,
		dataTask: URLSessionDataTask,
		didReceive response: URLResponse,
		completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void
	) {
		guard let response = response as? HTTPURLResponse else {
			completionHandler(.cancel)
			finish(
				taskIdentifier: dataTask.taskIdentifier,
				throwing: HTTPTransportError.invalidResponse(dataTask.currentRequest?.url)
			)
			return
		}
		continuation(for: dataTask.taskIdentifier)?.yield(.response(response))
		completionHandler(.allow)
	}

	func urlSession(
		_ session: URLSession,
		task: URLSessionTask,
		willPerformHTTPRedirection response: HTTPURLResponse,
		newRequest request: URLRequest,
		completionHandler: @escaping @Sendable (URLRequest?) -> Void
	) {
		guard let url = request.url, redirectValidator?(url) != false else {
			completionHandler(nil)
			finish(
				taskIdentifier: task.taskIdentifier,
				throwing: HTTPTransportError.redirectRejected(
					request.url ?? URL(filePath: "/invalid-redirect")
				)
			)
			return
		}
		completionHandler(request)
	}

	func urlSession(
		_ session: URLSession,
		dataTask: URLSessionDataTask,
		didReceive data: Data
	) {
		continuation(for: dataTask.taskIdentifier)?.yield(.data(data))
	}

	func urlSession(
		_ session: URLSession,
		task: URLSessionTask,
		didCompleteWithError error: (any Error)?
	) {
		finish(taskIdentifier: task.taskIdentifier, throwing: error)
	}

	private func continuation(for taskIdentifier: Int) -> Continuation? {
		lock.withLock { continuations[taskIdentifier] }
	}

	private func removeContinuation(for taskIdentifier: Int?) {
		guard let taskIdentifier else { return }
		_ = lock.withLock { continuations.removeValue(forKey: taskIdentifier) }
	}

	private func finish(taskIdentifier: Int, throwing error: (any Error)?) {
		let continuation = lock.withLock { continuations.removeValue(forKey: taskIdentifier) }
		if let error {
			continuation?.finish(throwing: error)
		} else {
			continuation?.finish()
		}
	}
}
