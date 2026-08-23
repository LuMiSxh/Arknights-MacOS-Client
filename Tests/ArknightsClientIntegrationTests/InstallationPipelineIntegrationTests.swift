// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@Suite(
	"Fresh onboarding and installation",
	.enabled(
		if: IntegrationTestGate.isEnabled,
		Comment(rawValue: IntegrationTestGate.disabledComment)
	),
	.serialized
)
@MainActor
struct InstallationPipelineIntegrationTests {
	@Test
	func onboardingInstallsAndPersistsIntoAnIsolatedEnvironment() async throws {
		let environment = try IntegrationTestEnvironment()
		defer { environment.cleanUp() }
		let network = try LocalFixtureNetwork()
		LocalFixtureURLProtocol.handler = network.response(for:)
		defer { LocalFixtureURLProtocol.handler = nil }

		#expect(environment.preferences.selectedRegion() == .global)
		let installDirectory = environment.paths.gameInstall(for: .global)
		environment.preferences.setSelectedRegion(.global)
		environment.preferences.setInstallDirectory(installDirectory, for: .global)
		environment.preferences.setAutomaticGameUpdates(false)
		environment.preferences.setAutomaticLauncherUpdates(false)
		environment.preferences.setAnnouncementsEnabled(false)
		environment.preferences.setPlaysLauncherMusic(false)

		let api = LauncherAPI(session: environment.session)
		let installer = GameInstaller(
			api: api,
			session: environment.session,
			compatibilityManager: GameCompatibilityManager(active: [])
		)
		let model = LauncherViewModel(
			api: api,
			installer: installer,
			paths: environment.paths,
			preferences: environment.preferences,
			gameCompatibilityManager: GameCompatibilityManager(active: []),
			checkIntelTranslation: {
				IntelTranslationCheck(state: .available, diagnostics: "integration-fixture")
			},
			arguments: []
		)
		await model.refreshTask?.value
		let configuration = try #require(model.configuration)

		let onboardingStore = OnboardingProgressStore(defaults: environment.defaults)
		let onboarding = OnboardingCoordinator(store: onboardingStore)
		await onboarding.startIfNeeded(
			isDeveloperMode: false,
			isOnboardingPreview: false,
			gameIsInstalled: model.isInstalled,
			checkForUpdates: { .current },
			checkIntelTranslation: { .available }
		)
		#expect(onboarding.isPresented)
		#expect(onboarding.step == .welcome)
		onboarding.advance()
		#expect(onboarding.step == .installation)

		let progress = IntegrationProgressRecorder()
		model.startInstallation(launchAfterCompletion: false)
		await model.installationTask?.value
		if let modelProgress = model.progress {
			await progress.record(modelProgress)
		}

		let payloadURL = installDirectory.appending(path: "Arknights.exe")
		let expectedPayload = try fixturePayload()
		#expect(configuration.gameLatestVersion == "1.2.3")
		#expect(configuration.executableName == "Arknights.exe")
		#expect(model.isInstalled)
		#expect(model.installedVersion == "1.2.3")
		#expect(try Data(contentsOf: payloadURL) == expectedPayload)
		#expect(
			!FileManager.default.fileExists(atPath: payloadURL.appendingPathExtension("part").path))

		let state = try #require(try installer.loadState(from: installDirectory))
		#expect(state.version == "1.2.3")
		#expect(state.basis == "fixture-manifest.json")
		#expect(state.source == "fixture-source")
		#expect(state.files?.map(\.path) == ["Arknights.exe"])
		let finalProgress = try #require(await progress.updates().last)
		#expect(finalProgress.fraction == 1)
		#expect(finalProgress.completedFiles == 1)

		for _ in 0..<10 where onboarding.isPresented {
			onboarding.advance()
		}
		#expect(!onboarding.isPresented, "Onboarding did not complete within ten steps")
		#expect(!onboardingStore.needsOnboarding)
		let completedOnboarding = OnboardingCoordinator(store: onboardingStore)
		await completedOnboarding.startIfNeeded(
			isDeveloperMode: false,
			isOnboardingPreview: false,
			gameIsInstalled: true,
			checkForUpdates: { .current },
			checkIntelTranslation: { .available }
		)
		#expect(!completedOnboarding.isPresented)

		let reloadedPreferences = LauncherPreferencesStore(defaults: environment.defaults)
		#expect(reloadedPreferences.selectedRegion() == .global)
		#expect(
			reloadedPreferences.installDirectory(
				for: .global,
				default: environment.paths.applicationSupportRoot
			) == installDirectory
		)

		let secondResult = try await installer.install(
			configuration: configuration,
			region: .global,
			into: installDirectory,
			progress: { _ in }
		)
		#expect(secondResult.downloadedFiles == 0)
		#expect(secondResult.downloadedBytes == 0)
		model.updateInstalledState()
		#expect(model.isInstalled, "The persisted installation must be discoverable after refresh")
		#expect(network.recorder.count(path: "/fixture-source/Arknights.exe") == 1)
		#expect(network.recorder.count(path: "/api/launcher/game/config") == 1)
		#expect(network.recorder.count(path: "/api/launcher/base/config") == 1)
		#expect(network.recorder.count(path: "/api/launcher/game/config/json") == 2)
		#expect(network.recorder.count(path: "/api/launcher/advanced/game/download/cdn") == 2)
		#expect(network.recorder.count(path: "/manifest.json") == 2)

		let apiRequests = network.recorder.recordedRequests().filter {
			$0.url?.host == "api-launcher-en.yo-star.com"
		}
		#expect(apiRequests.count == 6)
		#expect(
			apiRequests.allSatisfy {
				$0.value(forHTTPHeaderField: "Authorization")?.contains(
					#""game_tag":"Arknights_EN""#
				) == true
			}
		)
	}

	private func fixturePayload() throws -> Data {
		guard
			let url = Bundle.module.url(
				forResource: "fixture-payload",
				withExtension: "bin",
				subdirectory: "Fixtures"
			)
		else { throw IntegrationFixtureError.missingPayload }
		return try Data(contentsOf: url)
	}
}

private actor IntegrationProgressRecorder {
	private var recordedUpdates: [DownloadProgress] = []

	func record(_ update: DownloadProgress) {
		recordedUpdates.append(update)
	}

	func updates() -> [DownloadProgress] {
		recordedUpdates
	}
}

private enum IntegrationFixtureError: Error {
	case missingPayload
}

extension FixtureRequestRecorder {
	func count(path: String) -> Int {
		recordedRequests().count { $0.url?.path == path }
	}
}
