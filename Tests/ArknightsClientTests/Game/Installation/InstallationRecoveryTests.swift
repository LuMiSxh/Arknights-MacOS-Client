// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@MainActor
struct InstallationRecoveryTests {
	@Test(arguments: GameRegion.allCases)
	func retryUsesTheOriginalRegion(region: GameRegion) async {
		let fixture = makeInstallationFixture(region: region)
		let failureID = UUID()
		fixture.controller.presentInstallationFailure(
			LauncherError.checksumMismatch(path: "test", expected: "a", actual: "b"),
			id: failureID,
			operation: .install,
			region: region
		)
		#expect(fixture.controller.lifecycle.failure?.blocksGameLaunch == true)

		#expect(fixture.controller.retryInstallationFailure(id: failureID))
		await fixture.installer.waitForInstallationStart()
		#expect(await fixture.installer.requestedRegions() == [region])
		#expect(await fixture.installer.requestedVerificationModes() == [false])
		await fixture.installer.completeSuccessfully()
		await fixture.controller.waitForCurrentInstallation()
	}

	@Test
	func repairRetryPreservesFullVerification() async {
		let fixture = makeInstallationFixture(region: .global)
		fixture.controller.isInstalled = true
		let failureID = UUID()
		fixture.controller.presentInstallationFailure(
			LauncherError.checksumMismatch(path: "test", expected: "a", actual: "b"),
			id: failureID,
			operation: .repair,
			region: .global
		)

		#expect(fixture.controller.retryInstallationFailure(id: failureID))
		await fixture.installer.waitForInstallationStart()
		#expect(await fixture.installer.requestedVerificationModes() == [true])
		await fixture.installer.completeSuccessfully()
		await fixture.controller.waitForCurrentInstallation()
	}

	@Test
	func retryRejectsChangedRegionAndDuplicateSelection() async {
		let fixture = makeInstallationFixture(region: .global)
		let failureID = UUID()
		fixture.controller.presentInstallationFailure(
			LauncherError.checksumMismatch(path: "test", expected: "a", actual: "b"),
			id: failureID,
			operation: .install,
			region: .global
		)
		#expect(fixture.controller.selectRegion(.japan))
		fixture.controller.configuration = testGameConfiguration

		#expect(!fixture.controller.retryInstallationFailure(id: failureID))
		#expect(await fixture.installer.installationCount() == 0)

		#expect(fixture.controller.selectRegion(.global))
		fixture.controller.configuration = testGameConfiguration
		#expect(!fixture.controller.retryInstallationFailure(id: failureID))

		let currentFailureID = UUID()
		fixture.controller.presentInstallationFailure(
			LauncherError.checksumMismatch(path: "test", expected: "a", actual: "b"),
			id: currentFailureID,
			operation: .install,
			region: .global
		)
		#expect(fixture.controller.retryInstallationFailure(id: currentFailureID))
		await fixture.installer.waitForInstallationStart()
		#expect(!fixture.controller.retryInstallationFailure(id: currentFailureID))
		#expect(await fixture.installer.installationCount() == 1)
		await fixture.installer.completeSuccessfully()
		await fixture.controller.waitForCurrentInstallation()
	}

	@Test
	func confirmedRepairRevalidatesAndConsumesTheFailureOnce() async throws {
		let api = BlockingBrandingAPI()
		let installer = ControllableInstaller()
		let model = makeModel(api: api, installer: installer)
		await api.waitForBrandingRequest()
		await api.resolveBranding()
		await model.waitForStartup()
		model.installation.isInstalled = true
		let failureID = UUID()
		model.installation.presentInstallationFailure(
			LauncherError.checksumMismatch(path: "test", expected: "a", actual: "b"),
			id: failureID,
			operation: .update,
			region: .global
		)

		#expect(
			model.performRecoveryAction(.repair, failureID: failureID)
				== .repairConfirmationRequired
		)
		model.confirmRepair(failureID: failureID)
		await installer.waitForInstallationStart()
		model.confirmRepair(failureID: failureID)
		#expect(await installer.installationCount() == 1)
		#expect(await installer.requestedVerificationModes() == [true])
		await installer.completeSuccessfully()
		await model.installation.waitForCurrentInstallation()
	}

	@Test
	func repairConfirmationRejectsChangedStateAndRegion() async {
		let api = BlockingBrandingAPI()
		let installer = ControllableInstaller()
		let model = makeModel(api: api, installer: installer)
		await api.waitForBrandingRequest()
		await api.resolveBranding()
		await model.waitForStartup()
		model.installation.isInstalled = true
		let wrongRegionID = UUID()
		model.installation.presentInstallationFailure(
			LauncherError.gameCompatibility("test"),
			id: wrongRegionID,
			operation: .launch,
			region: .japan
		)
		model.confirmRepair(failureID: wrongRegionID)
		#expect(await installer.installationCount() == 0)

		let changedStateID = UUID()
		model.installation.presentInstallationFailure(
			LauncherError.checksumMismatch(path: "test", expected: "a", actual: "b"),
			id: changedStateID,
			operation: .update,
			region: .global
		)
		model.installation.isInstalled = false
		model.confirmRepair(failureID: changedStateID)
		#expect(await installer.installationCount() == 0)
	}
}

@MainActor
private func makeInstallationFixture(
	region: GameRegion
) -> (controller: InstallationController, installer: ControllableInstaller) {
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
	return (controller, installer)
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
