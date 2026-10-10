// SPDX-License-Identifier: MPL-2.0

import Foundation

/// Developer-mode flags and the action seam. Action bodies live in `LiveLauncherActions`
/// and, for debug builds, `SimulatedLauncherActions`; they never branch on developer mode.
extension LauncherViewModel {
	var isDeveloperMode: Bool {
		#if DEBUG
			developerSimulation != nil
		#else
			false
		#endif
	}

	var isOnboardingPreview: Bool {
		#if DEBUG
			developerSimulation?.onboardingPreview == true
		#else
			false
		#endif
	}

	var isRequiredOnboardingPreview: Bool {
		#if DEBUG
			developerSimulation?.onboardingRequired == true
		#else
			false
		#endif
	}

	/// The actions views call. Simulated while a developer simulation runs (debug builds only).
	var actions: any LauncherActions {
		#if DEBUG
			if developerSimulation != nil { return SimulatedLauncherActions(model: self) }
		#endif
		return liveActions
	}

	private var liveActions: LiveLauncherActions {
		LiveLauncherActions(
			lifecycle: lifecycle,
			settings: settings,
			installation: installation,
			gameSession: gameSession,
			intelTranslation: intelTranslation,
			customization: customization,
			communication: communication,
			refreshController: refreshController,
			preferences: preferences,
			log: log,
			waitForStartup: { [weak self] in await self?.waitForStartup() ?? true },
			pendingACEWarningRegion: { [weak self] in self?.pendingACEWarningRegion },
			setPendingACEWarningRegion: { [weak self] in self?.pendingACEWarningRegion = $0 }
		)
	}

	static func shouldPresentACEWarning(for region: GameRegion, acknowledged: Bool) -> Bool {
		LiveLauncherActions.shouldPresentACEWarning(for: region, acknowledged: acknowledged)
	}
}
