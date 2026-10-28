// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsCore

@Test
func issueReportURLIncludesOnlyApprovedFailureContext() {
	let emptyContext = URLComponents(
		url: IssueReportURL.build(runtimeName: nil, source: .settings),
		resolvingAgainstBaseURL: false
	)!
	#expect(emptyContext.host == "github.com")
	#expect(emptyContext.path == "/LuMiSxh/Arknights-MacOS-Client/issues/new")
	#expect(
		emptyContext.queryItems?.first { $0.name == "template" }?.value == "problem-report.yml")
	#expect(emptyContext.queryItems?.contains { $0.name == "logs" } == false)
	#expect(
		Set(emptyContext.queryItems?.map(\.name) ?? []) == [
			"template", "version", "environment", "source",
		],
		"empty context"
	)

	let failureContext = URLComponents(
		url: IssueReportURL.build(
			runtimeName: "Arknights macOS Runtime 0.7.0-rc2",
			code: .remoteContentInvalid,
			context: SupportContext(operation: .repair, region: .japan),
			source: .error
		), resolvingAgainstBaseURL: false)!

	#expect(failureContext.queryItems?.first { $0.name == "code" }?.value == "SV-CNT")
	#expect(
		failureContext.queryItems?.first { $0.name == "runtime" }?.value
			== "Arknights macOS Runtime 0.7.0-rc2")
	#expect(failureContext.queryItems?.first { $0.name == "operation" }?.value == "repair")
	#expect(failureContext.queryItems?.first { $0.name == "region" }?.value == "japan")
	#expect(
		Set(failureContext.queryItems?.map(\.name) ?? []) == [
			"template", "version", "runtime", "environment", "code", "operation", "region",
			"source",
		],
		"failure context"
	)
}

@Test(arguments: IssueReportSource.allCases)
func issueReportURLNamesTheSourceThatStartedTheReport(source: IssueReportSource) {
	let components = URLComponents(
		url: IssueReportURL.build(runtimeName: nil, source: source),
		resolvingAgainstBaseURL: false
	)!
	#expect(components.queryItems?.first { $0.name == "source" }?.value == source.rawValue)
}
