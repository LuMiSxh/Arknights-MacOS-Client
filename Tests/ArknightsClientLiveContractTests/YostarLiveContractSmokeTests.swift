// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@Suite(
	"Yostar launcher live contract",
	.enabled(if: LiveContractGate.isEnabled, Comment(rawValue: LiveContractGate.disabledComment)),
	.serialized
)
struct YostarLiveContractSmokeTests {
	@Test
	func supportedRegionsExposeAUsableInstallationContract() async throws {
		let environment = ProcessInfo.processInfo.environment
		let report = await YostarContractProbe().run(environment: environment)
		try report.writeIfRequested(environment: environment)

		for check in report.checks where check.status == .failed {
			Issue.record(
				Comment(
					rawValue:
						"\(check.region) \(check.contract) contract failed: \(check.summary)"
				)
			)
		}
	}
}
