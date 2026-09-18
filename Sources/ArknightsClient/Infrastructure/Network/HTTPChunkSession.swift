// SPDX-License-Identifier: MPL-2.0

import Foundation

enum HTTPTransportError: Error, Sendable {
	case invalidResponse(URL?)
	case responseTooLarge(URL, maximumBytes: Int)
	case responseSizeMismatch(URL, expected: Int64, actual: Int64)
	case redirectRejected(URL)
}

enum HTTPChunkEvent: Sendable {
	case response(HTTPURLResponse)
	case data(Data)
}

struct HTTPChunkStream: Sendable {
	let events: AsyncThrowingStream<HTTPChunkEvent, any Error>
	private let cancelHandler: @Sendable () -> Void
	private let acknowledgeHandler: @Sendable (Int) -> Void

	init(
		events: AsyncThrowingStream<HTTPChunkEvent, any Error>,
		cancelHandler: @escaping @Sendable () -> Void,
		acknowledgeHandler: @escaping @Sendable (Int) -> Void
	) {
		self.events = events
		self.cancelHandler = cancelHandler
		self.acknowledgeHandler = acknowledgeHandler
	}

	func cancel() {
		cancelHandler()
	}

	/// Releases a consumed chunk's bytes from the stream's ceiling. Every consumer must call
	/// this for every chunk, or the stream stays suspended once the ceiling is reached.
	func acknowledge(_ byteCount: Int) {
		acknowledgeHandler(byteCount)
	}
}

/// Bridges `URLSessionDataDelegate`'s callback-based streaming into an `AsyncThrowingStream`
/// per request, so callers can process each chunk as it arrives instead of buffering a whole
/// response in memory.
///
/// `AsyncThrowingStream` has no backpressure, so each stream counts its unacknowledged bytes
/// and suspends its task at the ceiling, letting TCP flow control slow the server down.
final class HTTPChunkSession: NSObject, URLSessionDataDelegate, @unchecked Sendable {
	private typealias Continuation = AsyncThrowingStream<HTTPChunkEvent, any Error>.Continuation

	private struct Subscriber {
		let continuation: Continuation
		weak var task: URLSessionDataTask?
		var bufferedBytes = 0
		var isSuspended = false
	}

	private let redirectValidator: (@Sendable (URL) -> Bool)?
	private let maximumBufferedBytes: Int
	private let delegateQueue: OperationQueue
	private let lock = NSLock()
	private var subscribers: [Int: Subscriber] = [:]
	private var session: URLSession!

	init(
		configuration: URLSessionConfiguration,
		redirectValidator: (@Sendable (URL) -> Bool)? = nil,
		maximumBufferedBytes: Int = AppConstants.Network.maximumBufferedStreamBytes
	) {
		self.redirectValidator = redirectValidator
		self.maximumBufferedBytes = maximumBufferedBytes
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
		let identifier = task.taskIdentifier
		lock.withLock {
			subscribers[identifier] = Subscriber(continuation: continuation, task: task)
		}
		continuation.onTermination = { @Sendable [weak self, weak task] _ in
			task?.cancel()
			self?.removeSubscriber(for: task?.taskIdentifier)
		}
		task.resume()
		return HTTPChunkStream(
			events: events,
			cancelHandler: { task.cancel() },
			acknowledgeHandler: { [weak self] byteCount in
				self?.acknowledge(byteCount, taskIdentifier: identifier)
			}
		)
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
		let continuation = lock.withLock { () -> Continuation? in
			guard var subscriber = subscribers[dataTask.taskIdentifier] else { return nil }
			subscriber.bufferedBytes += data.count
			if !subscriber.isSuspended, subscriber.bufferedBytes >= maximumBufferedBytes {
				subscriber.isSuspended = true
				dataTask.suspend()
			}
			subscribers[dataTask.taskIdentifier] = subscriber
			return subscriber.continuation
		}
		continuation?.yield(.data(data))
	}

	/// Resumes at half the ceiling, so a steady download does not suspend once per chunk.
	private func acknowledge(_ byteCount: Int, taskIdentifier: Int) {
		lock.withLock {
			guard var subscriber = subscribers[taskIdentifier] else { return }
			subscriber.bufferedBytes = max(0, subscriber.bufferedBytes - byteCount)
			if subscriber.isSuspended, subscriber.bufferedBytes <= maximumBufferedBytes / 2 {
				subscriber.isSuspended = false
				subscriber.task?.resume()
			}
			subscribers[taskIdentifier] = subscriber
		}
	}

	func urlSession(
		_ session: URLSession,
		task: URLSessionTask,
		didCompleteWithError error: (any Error)?
	) {
		finish(taskIdentifier: task.taskIdentifier, throwing: error)
	}

	private func continuation(for taskIdentifier: Int) -> Continuation? {
		lock.withLock { subscribers[taskIdentifier]?.continuation }
	}

	private func removeSubscriber(for taskIdentifier: Int?) {
		guard let taskIdentifier else { return }
		_ = lock.withLock { subscribers.removeValue(forKey: taskIdentifier) }
	}

	private func finish(taskIdentifier: Int, throwing error: (any Error)?) {
		let continuation = lock.withLock {
			subscribers.removeValue(forKey: taskIdentifier)?.continuation
		}
		if let error {
			continuation?.finish(throwing: error)
		} else {
			continuation?.finish()
		}
	}
}
