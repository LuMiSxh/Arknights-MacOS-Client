// SPDX-License-Identifier: MPL-2.0

import Foundation
import Synchronization

/// Serves canned HTTP answers to sessions built from a `Route`.
///
/// Each route has its own handler, request count and redirect, so suites that run in parallel do
/// not share state. A route marks its session with a header that this protocol reads back.
package final class StubURLProtocol: URLProtocol, @unchecked Sendable {
	package typealias Handler = (URLRequest) throws -> (HTTPURLResponse, Data)

	package final class Route: @unchecked Sendable {
		fileprivate let id = UUID().uuidString
		fileprivate let chunkSize: Int?
		private let lock = NSLock()
		private var storedHandler: Handler?
		private var storedRedirectURL: URL?
		private var storedRequestCount = 0

		/// - Parameter chunkSize: Splits each body into pieces of this size. `nil` sends one piece.
		package init(chunkSize: Int? = nil) {
			self.chunkSize = chunkSize
			StubURLProtocol.routes.withLock { $0[id] = self }
		}

		/// Answers every request. A request without a handler fails with `badServerResponse`.
		package var handler: Handler? {
			get { lock.withLock { storedHandler } }
			set { lock.withLock { storedHandler = newValue } }
		}

		/// Redirects the next request to this URL once, before the handler runs.
		package var redirectURL: URL? {
			get { lock.withLock { storedRedirectURL } }
			set { lock.withLock { storedRedirectURL = newValue } }
		}

		package var requestCount: Int { lock.withLock { storedRequestCount } }

		package var session: URLSession {
			let configuration = URLSessionConfiguration.ephemeral
			configure(configuration)
			return URLSession(configuration: configuration)
		}

		package func configure(_ configuration: URLSessionConfiguration) {
			configuration.protocolClasses = [StubURLProtocol.self]
			configuration.httpAdditionalHeaders = [StubURLProtocol.routeHeader: id]
		}

		fileprivate func begin() -> (handler: Handler?, redirectURL: URL?) {
			lock.withLock {
				storedRequestCount += 1
				let redirectURL = storedRedirectURL
				storedRedirectURL = nil
				return (storedHandler, redirectURL)
			}
		}
	}

	private static let routeHeader = "X-Stub-Route"
	private static let routes = Mutex<[String: Route]>([:])

	override package class func canInit(with request: URLRequest) -> Bool { true }
	override package class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

	override package func startLoading() {
		guard let id = request.value(forHTTPHeaderField: Self.routeHeader),
			let route = Self.routes.withLock({ $0[id] })
		else {
			client?.urlProtocol(self, didFailWithError: URLError(.resourceUnavailable))
			return
		}
		let (handler, redirectURL) = route.begin()
		if let redirectURL, let url = request.url {
			let response = HTTPURLResponse(
				url: url, statusCode: 302, httpVersion: "HTTP/1.1",
				headerFields: ["Location": redirectURL.absoluteString])!
			client?.urlProtocol(
				self, wasRedirectedTo: URLRequest(url: redirectURL), redirectResponse: response)
			return
		}
		do {
			guard let (response, data) = try handler?(request) else {
				throw URLError(.badServerResponse)
			}
			client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
			let size = route.chunkSize ?? max(data.count, 1)
			for start in stride(from: 0, to: data.count, by: size) {
				client?.urlProtocol(
					self, didLoad: data.subdata(in: start..<min(start + size, data.count)))
			}
			client?.urlProtocolDidFinishLoading(self)
		} catch {
			client?.urlProtocol(self, didFailWithError: error)
		}
	}

	override package func stopLoading() {}
}
