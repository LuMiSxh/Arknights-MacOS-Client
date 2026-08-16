// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@Test
func issueReportURLAlwaysTargetsTheBugReportTemplate() {
	let url = IssueReportURL.build()
	let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!

	#expect(components.host == "github.com")
	#expect(components.path == "/LuMiSxh/Arknights-MacOS-Client/issues/new")
	#expect(components.queryItems?.first { $0.name == "template" }?.value == "bug-report.yml")
	#expect(components.queryItems?.contains { $0.name == "problem" } == false)
}

@Test
func issueReportURLPercentEncodesTheProblemDescription() {
	let message = "Download failed: 50% complete & timed out\nretrying"
	let url = IssueReportURL.build(problem: message)
	let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!

	#expect(components.queryItems?.first { $0.name == "problem" }?.value == message)
}

@Test
func logTailReturnsWholeFileWhenSmallerThanTheLimit() throws {
	let url = try makeTemporaryFile(contents: "line one\nline two\n")
	defer { try? FileManager.default.removeItem(at: url) }

	#expect(IssueReportURL.tail(of: url, maximumBytes: 1_024) == "line one\nline two")
}

@Test
func logTailDropsAPossiblyTruncatedLeadingLine() throws {
	let lines = (1...50).map { "line \($0) of the log file" }
	let url = try makeTemporaryFile(contents: lines.joined(separator: "\n"))
	defer { try? FileManager.default.removeItem(at: url) }

	let tail = try #require(IssueReportURL.tail(of: url, maximumBytes: 40))

	#expect(tail == "line 50 of the log file")
}

private func makeTemporaryFile(contents: String) throws -> URL {
	let url = FileManager.default.temporaryDirectory
		.appendingPathComponent(UUID().uuidString)
	try contents.write(to: url, atomically: true, encoding: .utf8)
	return url
}
