// SPDX-License-Identifier: MPL-2.0

import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsCore
@testable import ArknightsGameInstallation

@MainActor
struct InstallationRecoveryTests {
	@Test
	func partialInstallCanBeUninstalledOnlyWhileIdle() throws {
		let fixture = try makeInstallationFixture(region: .global)
		defer { fixture.storage.remove() }
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
	func staleStateRefreshIsNotPublishedAfterRegionChange() async throws {
		let gate = StateLoaderGate()
		let fixture = try makeInstallationFixture(
			region: .global,
			stateLoader: { _ in
				await gate.wait()
				return InstallationStateSnapshot(
					isInstalled: true, hasPartialDownload: false, installedVersion: "1.0.0",
					installedRegions: [.global], diagnostic: nil)
			})
		defer { fixture.storage.remove() }
		let refresh = fixture.controller.updateInstalledState()
		#expect(fixture.controller.selectRegion(.japan))
		await gate.open()
		await refresh.value

		#expect(!fixture.controller.isInstalled)
		#expect(fixture.controller.installedVersion == nil)
		#expect(fixture.controller.installedRegions.isEmpty)
	}
}

private actor StateLoaderGate {
	private var continuation: CheckedContinuation<Void, Never>?
	private var isOpen = false

	func wait() async {
		guard !isOpen else { return }
		await withCheckedContinuation { continuation = $0 }
	}

	func open() {
		isOpen = true
		continuation?.resume()
		continuation = nil
	}
}

@MainActor
private struct InstallationFixture {
	let controller: InstallationController
	let installer: ControllableInstaller
	let preferences: LauncherPreferencesStore
	/// The test removes this in a `defer`.
	let storage: TemporaryDirectory
}

@MainActor
private func makeInstallationFixture(
	region: GameRegion,
	stateLoader: InstallationController.StateLoader? = nil
) throws -> InstallationFixture {
	let storage = try TemporaryDirectory("InstallationRecoveryTests")
	let root = storage.url
	let paths = AppPaths(
		applicationSupportDirectory: root.appending(path: "Support", directoryHint: .isDirectory),
		cachesDirectory: root.appending(path: "Caches", directoryHint: .isDirectory),
		libraryDirectory: root.appending(path: "Library", directoryHint: .isDirectory)
	)
	let preferences = LauncherPreferencesStore(defaults: makeIsolatedDefaults().defaults)
	let log = LauncherLog(fileURL: paths.launcherLogFile)
	let lifecycle = LauncherLifecycleStore(log: log)
	let installer = ControllableInstaller()
	let controller = InstallationController(
		lifecycle: lifecycle,
		installer: installer,
		paths: paths,
		preferences: preferences,
		log: log,
		region: region,
		stateLoader: stateLoader
	)
	controller.configuration = testGameConfiguration
	return InstallationFixture(
		controller: controller, installer: installer, preferences: preferences, storage: storage)
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
