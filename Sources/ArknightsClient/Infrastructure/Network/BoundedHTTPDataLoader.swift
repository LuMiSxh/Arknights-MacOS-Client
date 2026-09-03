// SPDX-License-Identifier: MPL-2.0

import Foundation

/// Streams an HTTP response into memory while enforcing a hard byte limit before appending.
struct BoundedHTTPDataLoader: Sendable {
	private let session: HTTPChunkSession

	init(
		session: URLSession = .shared,
		redirectValidator: @escaping @Sendable (URL) -> Bool = {
			$0.scheme?.lowercased() == "https"
		}
	) {
		self.session = HTTPChunkSession(
			configuration: session.configuration,
			redirectValidator: redirectValidator
		)
	}

	func data(
		for request: URLRequest,
		maximumBytes: Int
	) async throws -> (Data, HTTPURLResponse) {
		guard maximumBytes > 0 else {
			throw HTTPTransportError.responseTooLarge(
				request.url ?? URL(filePath: "/invalid-remote-request"),
				maximumBytes: maximumBytes
			)
		}
		let stream = session.stream(for: request)
		defer { stream.cancel() }
		let sourceURL = request.url ?? URL(filePath: "/invalid-remote-request")
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
