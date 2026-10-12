// SPDX-License-Identifier: MPL-2.0

import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsCore
@testable import ArknightsGameInstallation
@testable import ArknightsLauncherUI

@MainActor
struct InstallationRecoveryTests {
	@Test
	func successfulInstallationPublishesOneCompletionFeedback() async {
		let fixture = makeInstallationFixture(region: .global)
		fixture.controller.startInstallation(launchAfterCompletion: false)
		await fixture.installer.waitForInstallationStart()
		await fixture.installer.completeSuccessfully()
		#expect(await waitForCondition { fixture.controller.completionFeedback != nil })

		let feedback = fixture.controller.completionFeedback
		#expect(feedback?.region == .global)
		#expect(fixture.controller.lifecycle.state.presentation.status == .ready)
		#expect(!fixture.controller.finishInstallation(UUID()))
		#expect(fixture.controller.consumeCompletionFeedback(for: .japan) == nil)
		#expect(
			fixture.controller.consumeCompletionFeedback(for: .global)?.id == feedback?.id
		)
		#expect(fixture.controller.consumeCompletionFeedback(for: .global) == nil)

		let switching = makeInstallationFixture(region: .global)
		switching.controller.startInstallation(launchAfterCompletion: false)
		await switching.installer.waitForInstallationStart()
		await switching.installer.completeSuccessfully()
		#expect(await waitForCondition { switching.controller.completionFeedback != nil })
		#expect(switching.controller.selectRegion(.japan))
		#expect(switching.controller.completionFeedback == nil)
	}

	@Test(arguments: GameRegion.allCases)
	func retryUsesTheOriginalRegion(region: GameRegion) async {
		let fixture = makeInstallationFixture(region: region)
		let failureID = UUID()
		fixture.controller.presentInstallationFailure(
			InstallerError.checksumMismatch(path: "test", expected: "a", actual: "b"),
			id: failureID,
			operation: .install,
			region: region
		)
		#expect(fixture.controller.lifecycle.state.presentation.failure?.blocksGameLaunch == true)

		#expect(fixture.controller.retryInstallationFailure(id: failureID))
		await fixture.installer.waitForInstallationStart()
		#expect(await fixture.installer.requestedRegions() == [region])
		#expect(await fixture.installer.requestedVerificationModes() == [false])
		#expect(!fixture.controller.retryInstallationFailure(id: failureID))
		#expect(await fixture.installer.installationCount() == 1)
		await fixture.installer.completeSuccessfully()
		await fixture.controller.waitForCurrentInstallation()

		guard region == .global else { return }
		// A repair retry keeps full verification.
		fixture.controller.isInstalled = true
		let repairID = UUID()
		fixture.controller.presentInstallationFailure(
			InstallerError.checksumMismatch(path: "test", expected: "a", actual: "b"),
			id: repairID,
			operation: .repair,
			region: .global
		)
		#expect(fixture.controller.retryInstallationFailure(id: repairID))
		while await fixture.installer.requestedVerificationModes().count < 2 {
			await Task.yield()
		}
		#expect(await fixture.installer.requestedVerificationModes().last == true)
		await fixture.installer.completeSuccessfully()
		await fixture.controller.waitForCurrentInstallation()

		// A retry is rejected after the region changed.
		let staleID = UUID()
		fixture.controller.presentInstallationFailure(
			InstallerError.checksumMismatch(path: "test", expected: "a", actual: "b"),
			id: staleID,
			operation: .install,
			region: .global
		)
		#expect(fixture.controller.selectRegion(.japan))
		fixture.controller.configuration = testGameConfiguration
		#expect(!fixture.controller.retryInstallationFailure(id: staleID))
	}

	@Test
	func partialInstallCanBeUninstalledOnlyWhileIdle() {
		let fixture = makeInstallationFixture(region: .global)
		#expect(!fixture.controller.canUninstallGame)

		fixture.controller.isInstalled = true
		#expect(fixture.controller.canUninstallGame)
		fixture.controller.isInstalled = false
		fixture.controller.hasPartialDownload = true
		#expect(fixture.controller.canUninstallGame)

		fixture.controller.lifecycle.simulateActivity(.installing(id: UUID(), stage: .downloading))
		#expect(!fixture.controller.canUninstallGame)
		fixture.controller.lifecycle.simulateActivity(
			.runningGame(sessionID: UUID(), processIdentifier: 42))
		#expect(!fixture.controller.canUninstallGame)

		fixture.controller.lifecycle.simulateActivity(.idle)
		let failureID = UUID()
		fixture.controller.presentInstallationFailure(
			InstallerError.checksumMismatch(path: "test", expected: "a", actual: "b"),
			id: failureID,
			operation: .uninstall,
			region: .global
		)
		#expect(fixture.controller.retryUninstallFailure(id: failureID))
	}

	@Test
	func invalidConfigurationCannotSkipInstallationDiskPreflight() {
		let fixture = makeInstallationFixture(region: .global)
		fixture.controller.configuration = GameConfiguration(
			gameLowestVersion: "1", gameLatestVersion: "1", gameLatestFilePath: "manifest",
			gameStartExeName: "Arknights.exe", gameStartParams: [], gameUninstallScript: "",
			decompressionSize: "not a size")
		fixture.controller.startInstallation(launchAfterCompletion: false)
		#expect(fixture.controller.lifecycle.activity == .idle)
		#expect(fixture.controller.lifecycle.state.presentation.failure != nil)
	}
}

@MainActor
private func makeInstallationFixture(
	region: GameRegion
) -> (
	controller: InstallationController,
	installer: ControllableInstaller,
	preferences: LauncherPreferencesStore
) {
	let root = FileManager.default.temporaryDirectory.appending(
		path: "InstallationRecoveryTests.\(UUID().uuidString)",
		directoryHint: .isDirectory
	)
	let paths = AppPaths(
		applicationSupportDirectory: root.appending(path: "Support", directoryHint: .isDirectory),
		cachesDirectory: root.appending(path: "Caches", directoryHint: .isDirectory),
		libraryDirectory: root.appending(path: "Library", directoryHint: .isDirectory)
	)
	let defaults = UserDefaults(suiteName: "InstallationRecoveryTests.\(UUID().uuidString)")!
	let preferences = LauncherPreferencesStore(defaults: defaults)
	let log = LauncherLog(fileURL: paths.launcherLogFile)
	let lifecycle = LauncherLifecycleStore(log: log)
	let installer = ControllableInstaller()
	let controller = InstallationController(
		lifecycle: lifecycle,
		installer: installer,
		paths: paths,
		preferences: preferences,
		log: log,
		region: region
	)
	controller.configuration = testGameConfiguration
	return (controller, installer, preferences)
}

private let testGameConfiguration = GameConfiguration(
	gameLowestVersion: "1.0.0",
	gameLatestVersion: "2.0.0",
	gameLatestFilePath: "game.zip",
	gameStartExeName: "Arknights",
	gameStartParams: [],
	gameUninstallScript: "uninstall.exe",
	decompressionSize: "1 GB"
)
