// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

struct RosettaAvailabilityTests {
	@Test
	func onlyAvailableTranslationAllowsWine() {
		#expect(IntelTranslationState.available.allowsWine)
		#expect(!IntelTranslationState.waitingForLauncherCheck.allowsWine)
		#expect(!IntelTranslationState.checking.allowsWine)
		#expect(!IntelTranslationState.rosettaMissing.allowsWine)
		#expect(!IntelTranslationState.gameTestModeEnabled.allowsWine)
		#expect(!IntelTranslationState.unavailable.allowsWine)
		#expect(!IntelTranslationState.unsupportedOS.allowsWine)
	}

	@Test(arguments: [
		("Legacy Game Test Mode is enabled", true),
		("enabled", true),
		("Legacy Game Test Mode is disabled", false),
		("not enabled", false),
		("unavailable", false),
	])
	func gameTestModeStatusParsing(output: String, expected: Bool) {
		#expect(RosettaAvailability.gameTestModeIsEnabled(output) == expected)
	}

	@Test
	func macOS28IsRejectedBeforeRunningAProbe() async {
		let check = await RosettaAvailability.check(
			operatingSystemVersion: OperatingSystemVersion(
				majorVersion: 28,
				minorVersion: 0,
				patchVersion: 0
			),
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

	@Test
	func missingRuntimeMarkerRequiresRosetta() async {
		let check = await RosettaAvailability.check(
			operatingSystemVersion: macOS(27),
			operatingSystemVersionString: "Version 27",
			rosettaRuntimePresent: false,
			gameTestToolAvailable: false,
			runProcess: { _, _ in
				Issue.record("A missing Rosetta runtime must not start an Intel probe")
				return IntelTranslationProcessResult(status: 0, output: "")
			}
		)

		#expect(check.state == .rosettaMissing)
		#expect(check.diagnostics.contains("runtimeMarker=false"))
	}

	@Test
	func macOS27GameTestModeIsReportedBeforeTheIntelProbe() async {
		let check = await RosettaAvailability.check(
			operatingSystemVersion: macOS(27),
			operatingSystemVersionString: "Version 27",
			rosettaRuntimePresent: true,
			gameTestToolAvailable: true,
			runProcess: { executable, arguments in
				#expect(executable.lastPathComponent == "game-test-tool")
				#expect(arguments == ["status"])
				return IntelTranslationProcessResult(
					status: 0,
					output: "Legacy Game Test Mode is enabled"
				)
			}
		)

		#expect(check.state == .gameTestModeEnabled)
	}

	@Test(arguments: [(Int32(0), IntelTranslationState.available), (Int32(1), .unavailable)])
	func intelProbeDeterminesAvailability(status: Int32, expected: IntelTranslationState) async {
		let check = await RosettaAvailability.check(
			operatingSystemVersion: macOS(27),
			operatingSystemVersionString: "Version 27",
			rosettaRuntimePresent: true,
			gameTestToolAvailable: false,
			runProcess: { executable, arguments in
				#expect(executable.path == "/usr/bin/arch")
				#expect(arguments == ["-x86_64", "/usr/bin/true"])
				return IntelTranslationProcessResult(status: status, output: "")
			}
		)

		#expect(check.state == expected)
	}

	@Test
	func nestedBadCPUTypeErrorIsRecognized() {
		let badArchitecture = NSError(
			domain: NSPOSIXErrorDomain,
			code: Int(POSIXErrorCode.EBADARCH.rawValue)
		)
		let wrapped = NSError(
			domain: NSCocoaErrorDomain,
			code: NSFileReadUnknownError,
			userInfo: [NSUnderlyingErrorKey: badArchitecture]
		)

		#expect(RosettaAvailability.isBadCPUType(wrapped))
	}

	@Test
	func rosettaInstallerUsesApplesSoftwareUpdateTool() async throws {
		_ = try await RosettaInstaller.install { executable, arguments in
			#expect(executable.path == "/usr/sbin/softwareupdate")
			#expect(arguments == ["--install-rosetta", "--agree-to-license"])
			return IntelTranslationProcessResult(status: 0, output: "installed")
		}
	}

	private func macOS(_ majorVersion: Int) -> OperatingSystemVersion {
		OperatingSystemVersion(majorVersion: majorVersion, minorVersion: 0, patchVersion: 0)
	}
}
