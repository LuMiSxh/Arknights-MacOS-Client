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
		precondition(maximumBytes > 0)
		let stream = session.stream(for: request)
		defer { stream.cancel() }
		let sourceURL = request.url ?? URL(filePath: "/invalid-remote-request")
		var response: HTTPURLResponse?
		var accumulated = Data()

		return try await withTaskCancellationHandler {
			for try await event in stream.events {
				try Task.checkCancellation()
				switch event {
				case .response(let receivedResponse):
					guard response == nil else { throw LauncherError.invalidResponse }
					if receivedResponse.expectedContentLength > Int64(maximumBytes) {
						throw LauncherError.remoteContentTooLarge(
							sourceURL,
							maximumBytes: maximumBytes
						)
					}
					response = receivedResponse
				case .data(let chunk):
					guard response != nil else { throw LauncherError.invalidResponse }
					guard chunk.count <= maximumBytes - accumulated.count else {
						throw LauncherError.remoteContentTooLarge(
							sourceURL,
							maximumBytes: maximumBytes
						)
					}
					accumulated.append(chunk)
				}
			}

			guard let response else { throw LauncherError.invalidResponse }
			// A dropped connection can end the stream without the delegate ever
			// reporting an error, leaving `accumulated` silently short of what the
			// server promised — verify it before treating the transfer as complete,
			// so a truncated image is never cached and rendered as a corrupt file.
			if response.expectedContentLength >= 0,
				accumulated.count != response.expectedContentLength
			{
				throw LauncherError.downloadedSizeMismatch(
					path: sourceURL.absoluteString,
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
