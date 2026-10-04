// SPDX-License-Identifier: MPL-2.0

import Foundation
import Observation

/// Owns first-run presentation, resumable navigation, and the mandatory launcher-update
/// preflight checks. Individual steps apply settings through their feature controllers; the
/// coordinator never duplicates installation, networking, or asset persistence.
@MainActor
@Observable
final class OnboardingCoordinator {
	private let store: OnboardingProgressStore
	private var resumeStep: OnboardingStep?
	private var gameWasInstalled = false

	private(set) var isPresented = false
	private(set) var step: OnboardingStep = .welcome
	private(set) var updateState: OnboardingUpdateState = .checking
	private(set) var intelTranslationState: IntelTranslationState = .waitingForLauncherCheck
	/// Set while a returning player reruns a required setup schema; Skip Setup stays unavailable.
	private(set) var requiredSchema: Int?

	init(store: OnboardingProgressStore) {
		self.store = store
	}

	func startIfNeeded(
		isDeveloperMode: Bool,
		isOnboardingPreview: Bool,
		simulatesRequiredSetup: Bool = false,
		gameIsInstalled: Bool,
		checkForUpdates: @escaping @MainActor () async -> LauncherUpdateCheckOutcome,
		checkIntelTranslation: @escaping @MainActor () async -> IntelTranslationState = {
			(await RosettaAvailability.check()).state
		}
	) async {
		guard isOnboardingPreview || (!isDeveloperMode && store.needsOnboarding) else { return }
		if isOnboardingPreview {
			requiredSchema =
				simulatesRequiredSetup ? OnboardingProgressStore.currentSchemaVersion : nil
		} else {
			requiredSchema = store.pendingRequiredSchema
		}
		await begin(
			gameIsInstalled: gameIsInstalled,
			checkForUpdates: checkForUpdates,
			checkIntelTranslation: checkIntelTranslation
		)
	}

	func restart(
		gameIsInstalled: Bool,
		checkForUpdates: @escaping @MainActor () async -> LauncherUpdateCheckOutcome,
		checkIntelTranslation: @escaping @MainActor () async -> IntelTranslationState = {
			(await RosettaAvailability.check()).state
		}
	) async {
		store.reset()
		requiredSchema = nil
		await begin(
			gameIsInstalled: gameIsInstalled,
			checkForUpdates: checkForUpdates,
			checkIntelTranslation: checkIntelTranslation
		)
	}

	func retryUpdateCheck(
		_ checkForUpdates: @escaping @MainActor () async -> LauncherUpdateCheckOutcome,
		checkIntelTranslation: @escaping @MainActor () async -> IntelTranslationState = {
			(await RosettaAvailability.check()).state
		}
	) async {
		updateState = .checking
		updateState = Self.updateState(for: await checkForUpdates())
		await refreshIntelTranslationAvailability(checkIntelTranslation: checkIntelTranslation)
	}

	func refreshIntelTranslationAvailability(
		checkIntelTranslation: @MainActor () async -> IntelTranslationState = {
			(await RosettaAvailability.check()).state
		}
	) async {
		guard updateState.allowsSetup else {
			intelTranslationState = .waitingForLauncherCheck
			return
		}
		intelTranslationState = .checking
		intelTranslationState = await checkIntelTranslation()
	}

	func advance() {
		if step == .welcome {
			guard updateState.allowsSetup else { return }
			var target = resumeStep ?? .region
			if !gameWasInstalled && target.rawValue > OnboardingStep.region.rawValue {
				target = .region
			}
			resumeStep = nil
			move(to: target == .welcome ? .region : target)
			return
		}

		guard let next = step.next else {
			finish()
			return
		}
		move(to: next)
	}

	func goBack() {
		guard let previous = step.previous else { return }
		move(to: previous)
	}

	func skip() {
		guard updateState.allowsSetup, requiredSchema == nil else { return }
		store.complete()
		isPresented = false
	}

	func finish() {
		store.complete()
		isPresented = false
	}

	#if DEBUG
		func dismissDeveloperPreview() {
			isPresented = false
		}

		func simulateRequiredSetup(_ isRequired: Bool) {
			requiredSchema = isRequired ? OnboardingProgressStore.currentSchemaVersion : nil
		}
	#endif

	private func begin(
		gameIsInstalled: Bool,
		checkForUpdates: @escaping @MainActor () async -> LauncherUpdateCheckOutcome,
		checkIntelTranslation: @escaping @MainActor () async -> IntelTranslationState
	) async {
		gameWasInstalled = gameIsInstalled
		resumeStep = store.savedStep
		step = .welcome
		updateState = .checking
		intelTranslationState = .waitingForLauncherCheck
		isPresented = true
		updateState = Self.updateState(for: await checkForUpdates())
		await refreshIntelTranslationAvailability(
			checkIntelTranslation: checkIntelTranslation
		)
	}

	private func move(to target: OnboardingStep) {
		step = target
		store.save(step: target)
	}

	private static func updateState(
		for outcome: LauncherUpdateCheckOutcome
	) -> OnboardingUpdateState {
		switch outcome {
		case .current: .current
		case .updateAvailable(let version): .updateRequired(version)
		case .failed: .checkFailed
		}
	}
}
