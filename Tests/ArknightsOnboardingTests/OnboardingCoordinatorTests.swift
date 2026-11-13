// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsInfrastructure
import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsOnboarding

@MainActor
struct OnboardingCoordinatorTests {
	@Test
	func currentLauncherCanAdvanceAndResume() async {
		let (defaults, suiteName) = makeIsolatedDefaults("OnboardingCoordinatorTests")
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let store = OnboardingProgressStore(defaults: defaults)
		let coordinator = OnboardingCoordinator(store: store)

		await coordinator.startIfNeeded(
			isDeveloperMode: false,
			isOnboardingPreview: false,
			gameIsInstalled: true,
			checkForUpdates: { .current },
			checkIntelTranslation: { .available }
		)
		#expect(coordinator.isPresented)
		#expect(coordinator.step == .welcome)

		coordinator.advance()
		coordinator.advance()
		#expect(coordinator.step == .install)

		let resumed = OnboardingCoordinator(store: store)
		await resumed.startIfNeeded(
			isDeveloperMode: false,
			isOnboardingPreview: false,
			gameIsInstalled: true,
			checkForUpdates: { .current },
			checkIntelTranslation: { .available }
		)
		resumed.advance()

		#expect(resumed.step == .install)

		store.save(step: .look)
		let withoutGame = OnboardingCoordinator(store: store)
		await withoutGame.startIfNeeded(
			isDeveloperMode: false,
			isOnboardingPreview: false,
			gameIsInstalled: false,
			checkForUpdates: { .current },
			checkIntelTranslation: { .available }
		)
		withoutGame.advance()
		#expect(withoutGame.step == .region)

		defaults.set(5, forKey: "onboarding.currentStep")
		let fromEarlierLauncher = OnboardingCoordinator(
			store: OnboardingProgressStore(defaults: defaults))
		await fromEarlierLauncher.startIfNeeded(
			isDeveloperMode: false,
			isOnboardingPreview: false,
			gameIsInstalled: true,
			checkForUpdates: { .current },
			checkIntelTranslation: { .available }
		)
		#expect(fromEarlierLauncher.step == .welcome)
		fromEarlierLauncher.advance()
		#expect(fromEarlierLauncher.step == .region)
	}

	@Test
	func installStepFollowsServerAndPrecedesDisplay() {
		#expect(
			OnboardingStep.allCases == [
				.welcome, .region, .install, .display, .look, .extras, .finish,
			])
		#expect(OnboardingStep.region.next == .install)
		#expect(OnboardingStep.install.previous == .region)
		#expect(OnboardingStep.install.next == .display)
	}

	@Test
	func stepSavedOnTheOldRuntimeStepResumesOnInstall() {
		let (defaults, suiteName) = makeIsolatedDefaults("OnboardingCoordinatorTests")
		defer { defaults.removePersistentDomain(forName: suiteName) }
		defaults.set(16, forKey: "onboarding.currentStep")
		#expect(OnboardingProgressStore(defaults: defaults).savedStep == .install)
	}

	@Test
	func installStepDownloadsOnlyWhatIsMissing() {
		let complete = OnboardingInstallPlan(
			gameIsInstalled: true, gameIsDownloading: false, runtimeIsInstalled: true)
		#expect(!complete.needsDownload)
		#expect(complete.primaryTitle == "Continue")

		let downloading = OnboardingInstallPlan(
			gameIsInstalled: false, gameIsDownloading: true, runtimeIsInstalled: true)
		#expect(!downloading.gameNeedsDownload)
		#expect(downloading.primaryTitle == "Continue")

		let missingRuntime = OnboardingInstallPlan(
			gameIsInstalled: true, gameIsDownloading: false, runtimeIsInstalled: false)
		#expect(missingRuntime.runtimeNeedsDownload)
		#expect(!missingRuntime.gameNeedsDownload)
		#expect(missingRuntime.primaryTitle == "Download and Continue")

		let missingGame = OnboardingInstallPlan(
			gameIsInstalled: false, gameIsDownloading: false, runtimeIsInstalled: true)
		#expect(missingGame.gameNeedsDownload)
		#expect(missingGame.primaryTitle == "Download and Continue")
	}

	@Test(arguments: [
		("launcher update available", true),
		("launcher update check failed", false),
	])
	func launcherUpdateGateControlsSetupAndSkip(
		caseLabel: String,
		updateIsAvailable: Bool
	) async {
		let (defaults, suiteName) = makeIsolatedDefaults("OnboardingCoordinatorTests")
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let store = OnboardingProgressStore(defaults: defaults)
		let coordinator = OnboardingCoordinator(store: store)
		var intelChecks = 0
		await coordinator.startIfNeeded(
			isDeveloperMode: false,
			isOnboardingPreview: false,
			gameIsInstalled: false,
			checkForUpdates: {
				updateIsAvailable ? .updateAvailable("0.5.0") : .failed
			},
			checkIntelTranslation: {
				intelChecks += 1
				return .available
			}
		)
		#expect(intelChecks == (updateIsAvailable ? 0 : 1), Comment(rawValue: caseLabel))
		coordinator.advance()
		#expect(
			coordinator.step == (updateIsAvailable ? .welcome : .region),
			Comment(rawValue: caseLabel)
		)
		coordinator.skip()
		if updateIsAvailable {
			#expect(coordinator.step == .welcome, Comment(rawValue: caseLabel))
		} else {
			#expect(!coordinator.isPresented, Comment(rawValue: caseLabel))
			#expect(!store.needsOnboarding, Comment(rawValue: caseLabel))
		}

		#expect(
			coordinator.intelTranslationState
				== (updateIsAvailable ? .waitingForLauncherCheck : .available),
			Comment(rawValue: caseLabel))
		#expect(coordinator.isPresented == updateIsAvailable, Comment(rawValue: caseLabel))
		#expect(store.needsOnboarding == updateIsAvailable, Comment(rawValue: caseLabel))
	}

	@Test(.timeLimit(.minutes(1)))
	func retryDuringPendingCheckWinsOverStaleResult() async {
		let (defaults, suiteName) = makeIsolatedDefaults("OnboardingCoordinatorTests")
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let coordinator = OnboardingCoordinator(store: OnboardingProgressStore(defaults: defaults))
		var staleCheck: CheckedContinuation<LauncherUpdateCheckOutcome, Never>?
		let staleCheckStarted = Signal()
		var intelChecks = 0

		let first = Task {
			await coordinator.startIfNeeded(
				isDeveloperMode: false,
				isOnboardingPreview: false,
				gameIsInstalled: true,
				checkForUpdates: {
					await withCheckedContinuation { continuation in
						staleCheck = continuation
						staleCheckStarted.fire()
					}
				},
				checkIntelTranslation: {
					intelChecks += 1
					return .available
				}
			)
		}
		await staleCheckStarted.wait()

		await coordinator.retryUpdateCheck(
			{ .current },
			checkIntelTranslation: {
				intelChecks += 1
				return .available
			})
		staleCheck?.resume(returning: .updateAvailable("9.9.9"))
		await first.value

		#expect(coordinator.updateState == .current)
		#expect(coordinator.intelTranslationState == .available)
		#expect(intelChecks == 1)
	}

	@Test
	func requiredSetupCannotBeSkippedUntilFinished() async {
		let (defaults, suiteName) = makeIsolatedDefaults("OnboardingCoordinatorTests")
		defer { defaults.removePersistentDomain(forName: suiteName) }
		defaults.set(1, forKey: "onboarding.completedSchemaVersion")
		let store = OnboardingProgressStore(defaults: defaults)
		let coordinator = OnboardingCoordinator(store: store)

		await coordinator.startIfNeeded(
			isDeveloperMode: false,
			isOnboardingPreview: false,
			gameIsInstalled: true,
			checkForUpdates: { .current },
			checkIntelTranslation: { .available }
		)
		#expect(coordinator.requiredSchema == 4)

		coordinator.skip()
		#expect(coordinator.isPresented)
		#expect(store.needsOnboarding)

		coordinator.finish()
		#expect(!store.needsOnboarding)
		#expect(store.pendingRequiredSchema == nil)
	}

	@Test
	func navigatingBackAndForwardLeavesARunningDownloadAlone() async throws {
		let (defaults, suiteName) = makeIsolatedDefaults("OnboardingCoordinatorTests")
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let logURL = FileManager.default.temporaryDirectory.appending(
			path: "OnboardingCoordinatorTests.\(UUID().uuidString).log")
		defer { try? FileManager.default.removeItem(at: logURL) }  // best effort: temporary log
		let lifecycle = LauncherLifecycleStore(log: LauncherLog(fileURL: logURL))
		let coordinator = OnboardingCoordinator(store: OnboardingProgressStore(defaults: defaults))
		await coordinator.startIfNeeded(
			isDeveloperMode: false,
			isOnboardingPreview: false,
			gameIsInstalled: true,
			checkForUpdates: { .current },
			checkIntelTranslation: { .available }
		)
		let installing = LauncherActivity.installing(id: UUID(), stage: .downloading)
		let lease = try #require(lifecycle.begin(installing))

		coordinator.advance()
		coordinator.advance()
		coordinator.advance()
		coordinator.goBack()
		coordinator.goBack()
		coordinator.goBack()

		#expect(lifecycle.activity == installing)
		#expect(lifecycle.end(lease))
	}
}
