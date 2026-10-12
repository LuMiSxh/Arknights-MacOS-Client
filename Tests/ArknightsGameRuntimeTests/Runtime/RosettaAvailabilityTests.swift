// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation
import Testing

@testable import ArknightsGameRuntime

struct RosettaAvailabilityTests {
	struct Scenario: @unchecked Sendable {
		var major = 27
		var runtimePresent = true
		var gameTestOutput: String?
		var probe: Result<Int32, NSError> = .success(0)
		var expected: IntelTranslationState
		var diagnostic: String?
	}

	private static let wrappedBadArchitecture = NSError(
		domain: NSCocoaErrorDomain,
		code: NSFileReadUnknownError,
		userInfo: [
			NSUnderlyingErrorKey: NSError(
				domain: NSPOSIXErrorDomain, code: Int(POSIXErrorCode.EBADARCH.rawValue))
		]
	)

	@Test(
		arguments: [
			Scenario(expected: .available),
			Scenario(probe: .success(1), expected: .unavailable),
			Scenario(
				probe: .failure(wrappedBadArchitecture), expected: .unavailable,
				diagnostic: "intelProbeError=EBADARCH"),
			Scenario(
				runtimePresent: false, expected: .rosettaMissing, diagnostic: "runtimeMarker=false"),
			Scenario(
				gameTestOutput: "Legacy Game Test Mode is enabled", expected: .gameTestModeEnabled),
			Scenario(gameTestOutput: "Legacy Game Test Mode is disabled", expected: .available),
		]
	)
	func intelProbeDeterminesAvailability(scenario: Scenario) async {
		let check = await RosettaAvailability.check(
			operatingSystemVersion: OperatingSystemVersion(
				majorVersion: scenario.major, minorVersion: 0, patchVersion: 0),
			operatingSystemVersionString: "Version \(scenario.major)",
			rosettaRuntimePresent: scenario.runtimePresent,
			gameTestToolAvailable: scenario.gameTestOutput != nil,
			runProcess: { executable, arguments in
				if executable.lastPathComponent == "game-test-tool" {
					return IntelTranslationProcessResult(
						status: 0, output: scenario.gameTestOutput ?? "")
				}
				#expect(scenario.runtimePresent, "A missing Rosetta runtime must not start a probe")
				#expect(executable.path == "/usr/bin/arch")
				#expect(arguments == ["-x86_64", "/usr/bin/true"])
				return IntelTranslationProcessResult(
					status: try scenario.probe.get(), output: "")
			}
		)

		#expect(check.state == scenario.expected)
		if let diagnostic = scenario.diagnostic {
			#expect(check.diagnostics.contains(diagnostic))
		}
	}

	@Test
	func macOS28IsRejectedBeforeRunningAProbe() async {
		let check = await RosettaAvailability.check(
			operatingSystemVersion: OperatingSystemVersion(
				majorVersion: 28, minorVersion: 0, patchVersion: 0),
			operatingSystemVersionString: "Version 28",
			rosettaRuntimePresent: true,
			gameTestToolAvailable: true,
			runProcess: { _, _ in
				Issue.record("The Intel probe must not run on unsupported macOS versions")
				return IntelTranslationProcessResult(status: 0, output: "")
			}
		)

		#expect(check.state == .unsupportedOS)
	}
}
