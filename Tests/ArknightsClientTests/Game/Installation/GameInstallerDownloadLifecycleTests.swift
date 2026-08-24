// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@Suite(.serialized)
struct GameInstallerDownloadLifecycleTests {
	@Test
	func waitsForTheProgressMonitorBeforeReturningAnError() async throws {
		let fixture = try GameInstallerStreamingTests.makeFixture(
			body: Data("game".utf8),
			protocolClass: LifecycleURLProtocol.self
		)
		defer { fixture.remove() }
		let monitorGate = ProgressCallbackGate()
		let completion = DownloadCompletion()
		let operation = Task {
			do {
				_ = try await fixture.installer.download(
					fixture.item,
					source: fixture.source,
					baseURL: fixture.baseURL,
					installDirectory: fixture.directory,
					counter: ProgressCounter(totalBytes: fixture.item.byteCount, totalFiles: 1),
					progress: { update in await monitorGate.record(update) }
				)
				await completion.record(failed: false)
			} catch {
				await completion.record(failed: true)
			}
		}

		await monitorGate.waitUntilEntered()
		try await Task.sleep(for: .milliseconds(500))
		#expect(!(await completion.finished))
		await monitorGate.release()
		await operation.value
		#expect(await completion.finished)
		#expect(await completion.failed)
	}

	@Test
	func waitsForTheProgressMonitorBeforeReturningCancellation() async throws {
		let fixture = try GameInstallerStreamingTests.makeFixture(
			body: Data("game".utf8),
			protocolClass: LifecycleURLProtocol.self
		)
		defer { fixture.remove() }
		let monitorGate = ProgressCallbackGate()
		let completion = DownloadCompletion()
		let operation = Task {
			do {
				_ = try await fixture.installer.download(
					fixture.item,
					source: fixture.source,
					baseURL: fixture.baseURL,
					installDirectory: fixture.directory,
					counter: ProgressCounter(totalBytes: fixture.item.byteCount, totalFiles: 1),
					progress: { update in await monitorGate.record(update) }
				)
				await completion.record(failed: false)
			} catch {
				await completion.record(failed: true)
			}
		}

		await monitorGate.waitUntilEntered()
		operation.cancel()
		try await Task.sleep(for: .milliseconds(250))
		#expect(!(await completion.finished))
		await monitorGate.release()
		await operation.value
		#expect(await completion.finished)
		#expect(await completion.failed)
	}
}

private actor ProgressCallbackGate {
	private var entered = false
	private var waiters: [CheckedContinuation<Void, Never>] = []
	private var releaseContinuation: CheckedContinuation<Void, Never>?

	func record(_ update: DownloadProgress) async {
		guard update.sequence == 1, !entered else { return }
		entered = true
		for waiter in waiters { waiter.resume() }
		waiters.removeAll()
		await withCheckedContinuation { releaseContinuation = $0 }
	}

	func waitUntilEntered() async {
		guard !entered else { return }
		await withCheckedContinuation { waiters.append($0) }
	}

	func release() {
		releaseContinuation?.resume()
		releaseContinuation = nil
	}
}

private actor DownloadCompletion {
	private(set) var finished = false
	private(set) var failed = false

	func record(failed: Bool) {
		self.failed = failed
		finished = true
	}
}

private final class LifecycleURLProtocol: URLProtocol, @unchecked Sendable {
	private let lock = NSLock()
	private var stopped = false

	override class func canInit(with request: URLRequest) -> Bool { true }
	override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

	override func startLoading() {
		guard let url = request.url else {
			client?.urlProtocol(self, didFailWithError: URLError(.badURL))
			return
		}
		let response = HTTPURLResponse(
			url: url,
			statusCode: 200,
			httpVersion: "HTTP/1.1",
			headerFields: nil
		)!
		client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
		DispatchQueue.global().asyncAfter(deadline: .now() + 1.3) { [weak self] in
			guard let self, !self.isStopped else { return }
			self.client?.urlProtocol(
				self,
				didLoad: Data(repeating: 0xFF, count: 8)
			)
			self.client?.urlProtocolDidFinishLoading(self)
		}
	}

	override func stopLoading() {
		lock.withLock { stopped = true }
	}

	private var isStopped: Bool {
		lock.withLock { stopped }
	}
}
