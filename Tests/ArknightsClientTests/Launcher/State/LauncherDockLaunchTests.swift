// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@MainActor
struct LauncherDockLaunchTests {
	@Test
	func dockLaunchWaitsForRegionRefreshAndRejectsAnActiveSession() async throws {
		let api = BlockingBrandingAPI()
		let model = makeModel(api: api, installer: ControllableInstaller())
		await api.waitForBrandingRequest()
		await api.resolveBranding()
		await model.waitForStartup()

		let japanDirectory = model.preferences.installDirectory(
			for: .japan,
			default: model.installation.paths.gameInstall(for: .japan)
		)
		try FileManager.default.createDirectory(
			at: japanDirectory,
			withIntermediateDirectories: true
		)
		defer { try? FileManager.default.removeItem(at: japanDirectory) }
		try Data().write(to: japanDirectory.appending(path: "Arknights.exe"))
		let installedState = InstalledState(
			version: "1.0.0",
			basis: "test",
			source: "test",
			installedAt: .now,
			files: nil
		)
		let encoder = JSONEncoder()
		encoder.dateEncodingStrategy = .iso8601
		try encoder.encode(installedState).write(
			to: japanDirectory.appending(path: AppConstants.Game.installedStateFileName)
		)

		model.lifecycle.activity = .runningGame(sessionID: UUID(), processIdentifier: 42)
		#expect(!(await model.launchFromDock(region: .japan)))
		#expect(model.installation.region == .global)

		model.lifecycle.activity = .idle
		model.lifecycle.intelTranslationState = .unavailable
		let launch = Task { await model.launchFromDock(region: .japan) }
		await api.waitForBrandingRequests(2)
		#expect(model.installation.region == .japan)
		#expect(model.lifecycle.refresh.isChecking)

		await api.resolveBranding()
		#expect(!(await launch.value))
		#expect(model.installation.isInstalled)
		#expect(model.preferences.selectedRegion() == .japan)
		#expect(model.lifecycle.activity == .idle)
	}
}
