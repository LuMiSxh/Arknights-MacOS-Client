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
	#expect(components.queryItems?.contains { $0.name == "logs" } == false)
	#expect(
		Set(components.queryItems?.map(\.name) ?? []) == ["template", "version", "environment"]
	)
}

@Test
func issueReportURLIncludesOnlyApprovedFailureContext() {
	let url = IssueReportURL.build(
		code: .pebble,
		context: SupportContext(operation: .repair, region: .japan)
	)
	let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!

	#expect(components.queryItems?.first { $0.name == "code" }?.value == "PEBBLE")
	#expect(components.queryItems?.first { $0.name == "operation" }?.value == "repair")
	#expect(components.queryItems?.first { $0.name == "region" }?.value == "japan")
	#expect(
		Set(components.queryItems?.map(\.name) ?? []) == [
			"template", "version", "environment", "code", "operation", "region",
		]
	)
}
