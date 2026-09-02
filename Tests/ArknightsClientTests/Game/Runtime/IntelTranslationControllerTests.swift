// SPDX-License-Identifier: MPL-2.0

import Darwin
import Foundation
import Testing

@testable import ArknightsClient

@MainActor
struct IntelTranslationControllerTests {
	@Test
	func successfulInstallationRepeatsTheFunctionalProbe() async {
		let checks = TranslationCheckSequence(states: [.rosettaMissing, .available])
		let installer = RosettaInstallationRecorder(status: 0)
		let lifecycle = makeLifecycleStore()
		let controller = IntelTranslationController(
			lifecycle: lifecycle,
			checkIntelTranslation: { await checks.next() },
			installRosettaSystemSoftware: { await installer.install() }
		)

		#expect(await controller.refreshAvailability() == .rosettaMissing)
		let state = await controller.installRosetta()

		#expect(state == .available)
		#expect(lifecycle.intelTranslationState == .available)
		#expect(lifecycle.rosettaInstallationState == .idle)
		#expect(await checks.count == 2)
		#expect(await installer.count == 1)
	}

	@Test
	func failedInstallationKeepsLaunchBlockedAndExposesRecovery() async {
		let installer = RosettaInstallationRecorder(status: 7)
		let lifecycle = makeLifecycleStore()
		lifecycle.intelTranslationState = .rosettaMissing
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
		#expect(
			controller.installationActionTitle
				== L10n.string(.Launcher.launcherRosettaActionInstallAgain)
		)
		#expect(
			lifecycle.rosettaInstallationState.failureMessage
				== L10n.string(.Launcher.launcherRosettaFailureInstallerExited("7"))
		)
		#expect(lifecycle.failure?.blocksGameLaunch == true)
	}

	@Test
	func concurrentAvailabilityRequestsShareOneProbe() async {
		let checks = TranslationCheckSequence(states: [.available])
		let lifecycle = makeLifecycleStore()
		lifecycle.intelTranslationState = .checking
		let controller = IntelTranslationController(
			lifecycle: lifecycle,
			checkIntelTranslation: { await checks.next() }
		)

		async let first = controller.refreshAvailability()
		async let second = controller.refreshAvailability(force: true)
		let states = await (first, second)

		#expect(states.0 == .available)
		#expect(states.1 == .available)
		#expect(await checks.count == 1)
	}

	@Test(
		arguments: [
			(IntelTranslationState.rosettaMissing, SupportCode?.some(.limpet)),
			(.gameTestModeEnabled, SupportCode?.some(.limpet)),
			(.unavailable, SupportCode?.some(.limpet)),
			(.unsupportedOS, SupportCode?.some(.limpet)),
			(.available, SupportCode?.none),
			(.checking, SupportCode?.none),
		]
	)
	func readinessExposesLimpetOnlyForTerminalBlockedStates(
		fixture: (IntelTranslationState, SupportCode?)
	) {
		let lifecycle = makeLifecycleStore()
		lifecycle.intelTranslationState = fixture.0
		let controller = IntelTranslationController(lifecycle: lifecycle)

		#expect(controller.supportCode == fixture.1)
	}

	@Test
	func cancelledCallerDoesNotDiscardTheSharedProbeResult() async {
		let probe = BlockingTranslationProbe()
		let lifecycle = makeLifecycleStore()
		lifecycle.intelTranslationState = .checking
		let controller = IntelTranslationController(
			lifecycle: lifecycle,
			checkIntelTranslation: { await probe.waitForResult() }
		)

		let request = Task { await controller.refreshAvailability() }
		await probe.waitForRequest()
		request.cancel()
		await probe.resolve(IntelTranslationCheck(state: .available, diagnostics: "test"))
		_ = await request.value

		#expect(lifecycle.intelTranslationState == .available)
	}

	@Test
	func retryConsumesOnlyTheCurrentRosettaFailure() async throws {
		let installer = RosettaInstallationRecorder(status: 7)
		let lifecycle = makeLifecycleStore()
		lifecycle.intelTranslationState = .rosettaMissing
		let controller = IntelTranslationController(
			lifecycle: lifecycle,
			checkIntelTranslation: {
				IntelTranslationCheck(state: .rosettaMissing, diagnostics: "test")
			},
			installRosettaSystemSoftware: { await installer.install() }
		)
		_ = await controller.installRosetta()
		let failureID = try #require(lifecycle.failure?.id)

		#expect(!controller.retryRosettaFailure(id: UUID()))
		#expect(controller.retryRosettaFailure(id: failureID))
		#expect(!controller.retryRosettaFailure(id: failureID))
		await installer.waitForInstallations(2)
		#expect(await installer.count == 2)
	}

	@Test
	func translationProcessCancellationWaitsForChildExit() async throws {
		let clock = ContinuousClock()
		let started = clock.now
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
		let deadline = clock.now.advanced(by: .seconds(1))
		while !FileManager.default.fileExists(atPath: pidFile.path), clock.now < deadline {
			await Task.yield()
		}
		try #require(FileManager.default.fileExists(atPath: pidFile.path))
		task.cancel()
		await #expect(throws: CancellationError.self) { _ = try await task.value }
		#expect(started.duration(to: clock.now) < .seconds(2))
		let pid = try #require(
			Int32(
				try String(contentsOf: pidFile, encoding: .utf8)
					.trimmingCharacters(in: .whitespacesAndNewlines)
			)
		)
		#expect(Darwin.kill(pid, 0) == -1)
		#expect(errno == ESRCH)
	}

	@Test
	func translationProcessDrainsAndBoundsLargeOutput() async throws {
		let result = try await IntelTranslationProcess.run(
			executable: URL(filePath: "/bin/sh"),
			arguments: [
				"-c", "yes 0123456789abcdef | head -c 262144; printf 'FINAL-SUFFIX'",
			])
		#expect(result.status == 0)
		#expect(!result.output.isEmpty)
		#expect(result.output.utf8.count <= AppConstants.IO.processDiagnosticMaximumBytes)
		#expect(result.output.hasSuffix("FINAL-SUFFIX"))
	}
}

@MainActor
private func makeLifecycleStore() -> LauncherLifecycleStore {
	let fileURL = FileManager.default.temporaryDirectory.appending(
		path: "IntelTranslationControllerTests.\(UUID().uuidString).log"
	)
	return LauncherLifecycleStore(log: LauncherLog(fileURL: fileURL))
}

private actor BlockingTranslationProbe {
	private var requestContinuation: CheckedContinuation<Void, Never>?
	private var resultContinuation: CheckedContinuation<IntelTranslationCheck, Never>?
	private var didRequest = false

	func waitForResult() async -> IntelTranslationCheck {
		didRequest = true
		requestContinuation?.resume()
		requestContinuation = nil
		return await withCheckedContinuation { resultContinuation = $0 }
	}

	func waitForRequest() async {
		guard !didRequest else { return }
		await withCheckedContinuation { requestContinuation = $0 }
	}

	func resolve(_ result: IntelTranslationCheck) {
		resultContinuation?.resume(returning: result)
		resultContinuation = nil
	}
}
