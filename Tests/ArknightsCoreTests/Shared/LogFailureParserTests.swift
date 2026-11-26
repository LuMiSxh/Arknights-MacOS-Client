// SPDX-License-Identifier: MPL-2.0

import Testing

@testable import ArknightsCore

struct LogFailureParserTests {
	@Test(arguments: [
		(
			#"""
			2026-11-26T12:00:00.000Z WARN  app failure-suppressed code=none operation=launch
			2026-11-26T12:00:01.000Z INFO  app started version=1.0.2
			2026-11-26T12:00:02.000Z ERROR app failure-presented code=install-failed operation=install detail="download failed: \"retry\""
			2026-11-26T12:00:03.000Z ERROR app failure-presented code=none operation=launch detail="bad \\ path"
			"""#,
			[
				DiagnosticsEnvironment.Failure(
					time: "2026-11-26T12:00:02.000Z", code: "install-failed",
					operation: "install"),
				DiagnosticsEnvironment.Failure(
					time: "2026-11-26T12:00:03.000Z", code: "none", operation: "launch"),
			]
		),
		(
			(0..<6).map {
				"2026-11-26T12:00:0\($0).000Z ERROR app failure-presented code=c\($0) operation=launch"
			}.joined(separator: "\n"),
			(1..<6).map {
				DiagnosticsEnvironment.Failure(
					time: "2026-11-26T12:00:0\($0).000Z", code: "c\($0)", operation: "launch")
			}
		),
	])
	func parsesTheLastPresentedFailures(
		logText: String, expected: [DiagnosticsEnvironment.Failure]
	) {
		#expect(LogFailureParser.failures(inLogText: logText) == expected)
	}
}
