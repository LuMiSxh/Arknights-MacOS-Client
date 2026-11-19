// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameRuntime
import Foundation
import Observation

// Owns first-run presentation, resumable navigation, and the mandatory launcher-update
// preflight checks. Individual steps apply settings through their feature controllers; the
// coordinator never duplicates installation, networking, or asset persistence.
@MainActor
@Observable
package final class OnboardingCoordinator {
	private let store: OnboardingProgressStore
	private var resumeStep: OnboardingStep?
	private var gameWasInstalled = false
	// A newer launcher check or restart makes older results stale; the intel check has its own
	// slot because a manual refresh must not cancel the launcher check.
	private let updateSlot = TaskSlot()
	private let intelSlot = TaskSlot()
	let installRunner = OnboardingInstallRunner()

	package private(set) var isPresented = false
	private(set) var step: OnboardingStep = .welcome
	private(set) var direction: OnboardingTravelDirection = .forward
	private(set) var updateState: OnboardingUpdateState = .checking
	private(set) var intelTranslationState: IntelTranslationState = .waitingForLauncherCheck
	// Set while a returning player reruns a required setup schema; Skip Setup stays unavailable.
	private(set) var requiredSchema: Int?

	package init(store: OnboardingProgressStore) {
		self.store = store
	}

	package func startIfNeeded(
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

	package func restart(
		gameIsInstalled: Bool,
		checkForUpdates: @escaping @MainActor () async -> LauncherUpdateCheckOutcome,
		checkIntelTranslation: @escaping @MainActor () async -> IntelTranslationState = {
			(await RosettaAvailability.check()).state
		}
	) async {
		updateSlot.invalidate()
		intelSlot.invalidate()
		store.reset()
		requiredSchema = nil
		await begin(
			gameIsInstalled: gameIsInstalled,
			checkForUpdates: checkForUpdates,
			checkIntelTranslation: checkIntelTranslation
		)
	}

	package func retryUpdateCheck(
		_ checkForUpdates: @escaping @MainActor () async -> LauncherUpdateCheckOutcome,
		checkIntelTranslation: @escaping @MainActor () async -> IntelTranslationState = {
			(await RosettaAvailability.check()).state
		}
	) async {
		await runChecks(
			checkForUpdates: checkForUpdates, checkIntelTranslation: checkIntelTranslation)
	}

	func refreshIntelTranslationAvailability(
		checkIntelTranslation: @MainActor () async -> IntelTranslationState = {
			(await RosettaAvailability.check()).state
		}
	) async {
		let token = intelSlot.begin()
		guard updateState.allowsSetup else {
			intelTranslationState = .waitingForLauncherCheck
			return
		}
		intelTranslationState = .checking
		let result = await checkIntelTranslation()
		guard intelSlot.owns(token) else { return }
		intelTranslationState = result
	}

	private func runChecks(
		checkForUpdates: @MainActor () async -> LauncherUpdateCheckOutcome,
		checkIntelTranslation: @MainActor () async -> IntelTranslationState
	) async {
		let token = updateSlot.begin()
		intelSlot.invalidate()
		updateState = .checking
		intelTranslationState = .waitingForLauncherCheck
		let outcome = await checkForUpdates()
		guard updateSlot.owns(token) else { return }
		updateState = Self.updateState(for: outcome)
		await refreshIntelTranslationAvailability(checkIntelTranslation: checkIntelTranslation)
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
		package func dismissDeveloperPreview() {
			isPresented = false
		}

		package func simulateRequiredSetup(_ isRequired: Bool) {
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
		isPresented = true
		await runChecks(
			checkForUpdates: checkForUpdates, checkIntelTranslation: checkIntelTranslation)
	}

	// Navigation only changes the visible step. A running download or runtime install belongs to
	// its controller, so no step change cancels it.
	private func move(to target: OnboardingStep) {
		let order = OnboardingStep.allCases
		if let from = order.firstIndex(of: step), let to = order.firstIndex(of: target) {
			direction = to >= from ? .forward : .backward
		}
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
