// SPDX-License-Identifier: MPL-2.0

import Foundation
import Observation

/// Owns first-run presentation, resumable navigation, and the mandatory launcher-update
/// preflight checks. Individual steps apply settings through `LauncherViewModel`; the coordinator
/// never duplicates installation, networking, or asset persistence.
@MainActor
@Observable
final class OnboardingCoordinator {
	private let store: OnboardingProgressStore
	private var resumeStep: OnboardingStep?
	private var gameWasInstalled = false

	private(set) var isPresented = false
	private(set) var step: OnboardingStep = .welcome
	private(set) var updateState: OnboardingUpdateState = .checking
	private(set) var rosettaState: OnboardingRosettaState = .pending

	init(store: OnboardingProgressStore) {
		self.store = store
	}

	func startIfNeeded(
		isDeveloperMode: Bool,
		isOnboardingPreview: Bool,
		gameIsInstalled: Bool,
		checkForUpdates: @escaping @MainActor () async -> LauncherUpdateCheckOutcome,
		checkRosetta: @escaping @MainActor () -> Bool = { RosettaAvailability.isInstalled() }
	) async {
		guard isOnboardingPreview || (!isDeveloperMode && store.needsOnboarding) else { return }
		await begin(
			gameIsInstalled: gameIsInstalled,
			checkForUpdates: checkForUpdates,
			checkRosetta: checkRosetta
		)
	}

	func restart(
		gameIsInstalled: Bool,
		checkForUpdates: @escaping @MainActor () async -> LauncherUpdateCheckOutcome,
		checkRosetta: @escaping @MainActor () -> Bool = { RosettaAvailability.isInstalled() }
	) async {
		store.reset()
		await begin(
			gameIsInstalled: gameIsInstalled,
			checkForUpdates: checkForUpdates,
			checkRosetta: checkRosetta
		)
	}

	func retryUpdateCheck(
		_ checkForUpdates: @escaping @MainActor () async -> LauncherUpdateCheckOutcome,
		checkRosetta: @escaping @MainActor () -> Bool = { RosettaAvailability.isInstalled() }
	) async {
		updateState = .checking
		updateState = Self.updateState(for: await checkForUpdates())
		refreshRosettaAvailability(checkRosetta: checkRosetta)
	}

	func refreshRosettaAvailability(
		checkRosetta: @MainActor () -> Bool = { RosettaAvailability.isInstalled() }
	) {
		guard updateState.allowsSetup else {
			rosettaState = .pending
			return
		}
		rosettaState = checkRosetta() ? .available : .missing
	}

	func advance() {
		if step == .welcome {
			guard updateState.allowsSetup else { return }
			var target = resumeStep ?? .installation
			if !gameWasInstalled && target.rawValue > OnboardingStep.installation.rawValue {
				target = .installation
			}
			resumeStep = nil
			move(to: target == .welcome ? .installation : target)
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
		guard updateState.allowsSetup else { return }
		store.complete()
		isPresented = false
	}

	func finish() {
		store.complete()
		isPresented = false
	}

	private func begin(
		gameIsInstalled: Bool,
		checkForUpdates: @escaping @MainActor () async -> LauncherUpdateCheckOutcome,
		checkRosetta: @escaping @MainActor () -> Bool
	) async {
		gameWasInstalled = gameIsInstalled
		resumeStep = store.savedStep
		step = .welcome
		updateState = .checking
		rosettaState = .pending
		isPresented = true
		updateState = Self.updateState(for: await checkForUpdates())
		refreshRosettaAvailability(checkRosetta: checkRosetta)
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
		case .updateAvailable(let release): .updateRequired(release)
		case .unavailable, .failed: .checkFailed
		}
	}
}
