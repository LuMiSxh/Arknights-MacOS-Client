// SPDX-License-Identifier: MPL-2.0

import Foundation

/// Streams an HTTP response into memory while enforcing a hard byte limit before appending.
struct BoundedHTTPDataLoader: Sendable {
	private let session: HTTPChunkSession
	private let redirectValidator: (@Sendable (URL) -> Bool)?

	init(
		session: URLSession = .shared,
		redirectValidator: @escaping @Sendable (URL) -> Bool = {
			$0.scheme?.lowercased() == "https"
		}
	) {
		self.redirectValidator = redirectValidator
		self.session = HTTPChunkSession(
			configuration: session.configuration,
			redirectValidator: redirectValidator
		)
	}

	func data(
		for request: URLRequest,
		maximumBytes: Int,
		redirectValidator: (@Sendable (URL) -> Bool)? = nil
	) async throws -> (Data, HTTPURLResponse) {
		guard maximumBytes > 0 else {
			throw HTTPTransportError.responseTooLarge(
				request.url ?? URL(filePath: "/invalid-remote-request"),
				maximumBytes: maximumBytes
			)
		}
		let effectiveRedirectValidator = redirectValidator ?? self.redirectValidator
		let sourceURL = request.url ?? URL(filePath: "/invalid-remote-request")
		// An explicit per-request policy also owns the source URL; initializer-level policies
		// retain their historical redirect-only behavior for existing callers.
		if let redirectValidator {
			guard redirectValidator(sourceURL) else {
				throw HTTPTransportError.redirectRejected(sourceURL)
			}
		}
		let stream = session.stream(
			for: request,
			redirectValidator: effectiveRedirectValidator
		)
		defer { stream.cancel() }
		var response: HTTPURLResponse?
		var accumulated = Data()

		return try await withTaskCancellationHandler {
			do {
				for try await event in stream.events {
					try Task.checkCancellation()
					switch event {
					case .response(let receivedResponse):
						guard response == nil else {
							throw HTTPTransportError.invalidResponse(sourceURL)
						}
						if receivedResponse.expectedContentLength > Int64(maximumBytes) {
							throw HTTPTransportError.responseTooLarge(
								sourceURL,
								maximumBytes: maximumBytes
							)
						}
						response = receivedResponse
					case .data(let chunk):
						guard response != nil else {
							throw HTTPTransportError.invalidResponse(sourceURL)
						}
						guard chunk.count <= maximumBytes - accumulated.count else {
							throw HTTPTransportError.responseTooLarge(
								sourceURL,
								maximumBytes: maximumBytes
							)
						}
						accumulated.append(chunk)
						stream.acknowledge(chunk.count)
					}
				}
			} catch let error as URLError where error.code == .cancelled && Task.isCancelled {
				throw CancellationError()
			} catch let error as HTTPTransportError {
				if Task.isCancelled { throw CancellationError() }
				throw error
			}

			guard let response else {
				throw HTTPTransportError.invalidResponse(sourceURL)
			}
			if response.expectedContentLength >= 0,
				Int64(accumulated.count) != response.expectedContentLength
			{
				throw HTTPTransportError.responseSizeMismatch(
					sourceURL,
					expected: response.expectedContentLength,
					actual: Int64(accumulated.count)
				)
			}
			return (accumulated, response)
		} onCancel: {
			stream.cancel()
		}
	}
}
