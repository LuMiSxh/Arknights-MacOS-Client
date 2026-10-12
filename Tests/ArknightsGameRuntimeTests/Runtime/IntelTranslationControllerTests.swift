// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsTestSupport
import Darwin
import Foundation
import Testing

@testable import ArknightsGameRuntime

@MainActor
struct IntelTranslationControllerTests {
	@Test
	func failedInstallationKeepsLaunchBlockedAndExposesRecovery() async throws {
		let installer = RosettaInstallationRecorder(status: 7)
		let lifecycle = makeLifecycleStore()
		lifecycle.state.readiness.intelTranslation = .rosettaMissing
		let controller = IntelTranslationController(
			lifecycle: lifecycle,
			checkIntelTranslation: {
				IntelTranslationCheck(state: .rosettaMissing, diagnostics: "test")
			},
			installRosettaSystemSoftware: { await installer.install() }
		)

		let state = await controller.installRosetta()

		#expect(state == .rosettaMissing)
		guard case .rosettaMissing = controller.launchError else {
			Issue.record("Missing Rosetta must expose the matching launch error")
			return
		}
		#expect(controller.canInstallRosetta)
		#expect(lifecycle.state.presentation.failure?.actions.contains(.retry) == true)
		#expect(lifecycle.state.readiness.rosettaInstallation.failureMessage?.contains("7") == true)
		#expect(lifecycle.state.presentation.failure?.blocksGameLaunch == true)

		let failureID = try #require(lifecycle.state.presentation.failure?.id)
		#expect(!controller.retryRosettaFailure(id: UUID()))
		#expect(controller.retryRosettaFailure(id: failureID))
		#expect(!controller.retryRosettaFailure(id: failureID))
		await installer.waitForInstallations(2)
	}

	@Test
	func translationProcessDrainsAndBoundsLargeOutput() async throws {
		let result = try await IntelTranslationProcess.run(
			executable: URL(filePath: "/bin/sh"),
			arguments: ["-c", "yes 0123456789abcdef | head -c 262144; printf 'FINAL-SUFFIX'"])
		#expect(result.status == 0)
		#expect(result.output.utf8.count <= AppConstants.IO.processDiagnosticMaximumBytes)
		#expect(result.output.hasSuffix("FINAL-SUFFIX"))
	}

	@Test
	func translationProcessCancellationWaitsForChildExit() async throws {
		let clock = ContinuousClock()
		let pidFile = FileManager.default.temporaryDirectory.appending(
			path: "intel-process-\(UUID().uuidString).pid")
		defer { try? FileManager.default.removeItem(at: pidFile) }
		let task = Task {
			try await IntelTranslationProcess.run(
				executable: URL(filePath: "/bin/sh"),
				arguments: [
					"-c", "trap '' TERM; echo $$ > '\(pidFile.path)'; while :; do :; done",
				])
		}
		let processStarted = await waitForCondition(timeout: .seconds(5)) {
			FileManager.default.fileExists(atPath: pidFile.path)
		}
		try #require(processStarted)
		let cancellationStarted = clock.now
		task.cancel()
		await #expect(throws: CancellationError.self) { _ = try await task.value }
		#expect(cancellationStarted.duration(to: clock.now) < .seconds(2))
		let pid = try #require(
			Int32(
				try String(contentsOf: pidFile, encoding: .utf8)
					.trimmingCharacters(in: .whitespacesAndNewlines)
			)
		)
		#expect(Darwin.kill(pid, 0) == -1)
		#expect(errno == ESRCH)
	}
}
