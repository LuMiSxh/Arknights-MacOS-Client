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
