// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation

/// A UUID-named directory under the system temporary directory. Call `remove()` in a `defer`.
package struct TemporaryDirectory: Sendable {
	package let url: URL

	package init(_ label: String) throws {
		url = FileManager.default.temporaryDirectory.appending(
			path: "\(label).\(UUID().uuidString)", directoryHint: .isDirectory)
		try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
	}

	package func remove() {
		try? FileManager.default.removeItem(at: url)
	}
}

/// An HTTP/1.1 response for a stub route.
package func makeHTTPResponse(
	url: URL,
	status: Int,
	headers: [String: String] = [:]
) -> HTTPURLResponse {
	HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
}

/// A defaults suite that no other test shares. Remove it with `removePersistentDomain(forName:)`.
package func makeIsolatedDefaults(
	_ label: String = "Tests"
) -> (defaults: UserDefaults, suiteName: String) {
	let suiteName = "\(label).\(UUID().uuidString)"
	return (UserDefaults(suiteName: suiteName)!, suiteName)
}

/// A lifecycle store that logs into a throwaway file.
@MainActor
package func makeLifecycleStore() -> LauncherLifecycleStore {
	let fileURL = FileManager.default.temporaryDirectory.appending(
		path: "Lifecycle.\(UUID().uuidString).log")
	return LauncherLifecycleStore(log: LauncherLog(fileURL: fileURL))
}
