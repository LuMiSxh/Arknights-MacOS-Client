// SPDX-License-Identifier: MPL-2.0

import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsCore
@testable import ArknightsGameRuntime

/// A new launch keeps the last three sessions' logs in `*.previous.log` and
/// `*.previous-2.log`, and never rotates an empty log over a useful one.
struct SessionLogRotationTests {
	@Test
	func launchKeepsTheLastThreeSessions() throws {
		let temporary = try TemporaryDirectory("SessionLogRotationTests")
		defer { temporary.remove() }
		let log = temporary.url.appending(path: "unity.log")
		let previous = temporary.url.appending(path: "unity.previous.log")
		let previousSecond = temporary.url.appending(path: "unity.previous-2.log")

		try SessionLogRotation.rotate(log)  // Missing log.
		try Data("first".utf8).write(to: log)
		try SessionLogRotation.rotate(log)
		try Data("second".utf8).write(to: log)
		try SessionLogRotation.rotate(log)
		try Data("third".utf8).write(to: log)
		try SessionLogRotation.rotate(log)
		try Data().write(to: log)
		try SessionLogRotation.rotate(log)

		#expect(try String(contentsOf: previous, encoding: .utf8) == "third")
		#expect(try String(contentsOf: previousSecond, encoding: .utf8) == "second")
		#expect(FileManager.default.fileExists(atPath: log.path))
	}
}
