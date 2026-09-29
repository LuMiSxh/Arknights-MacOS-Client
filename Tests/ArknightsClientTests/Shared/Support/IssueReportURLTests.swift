// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@Test
func issueReportURLIncludesOnlyApprovedFailureContext() {
	let emptyContext = URLComponents(
		url: IssueReportURL.build(), resolvingAgainstBaseURL: false)!
	#expect(emptyContext.host == "github.com")
	#expect(emptyContext.path == "/LuMiSxh/Arknights-MacOS-Client/issues/new")
	#expect(
		emptyContext.queryItems?.first { $0.name == "template" }?.value == "bug-report.yml")
	#expect(emptyContext.queryItems?.contains { $0.name == "logs" } == false)
	#expect(
		Set(emptyContext.queryItems?.map(\.name) ?? []) == ["template", "version", "environment"],
		"empty context"
	)

	let failureContext = URLComponents(
		url: IssueReportURL.build(
			code: .pebble,
			context: SupportContext(operation: .repair, region: .japan)
		), resolvingAgainstBaseURL: false)!

	#expect(failureContext.queryItems?.first { $0.name == "code" }?.value == "PEBBLE")
	#expect(failureContext.queryItems?.first { $0.name == "operation" }?.value == "repair")
	#expect(failureContext.queryItems?.first { $0.name == "region" }?.value == "japan")
	#expect(
		Set(failureContext.queryItems?.map(\.name) ?? []) == [
			"template", "version", "environment", "code", "operation", "region",
		],
		"failure context"
	)
}
