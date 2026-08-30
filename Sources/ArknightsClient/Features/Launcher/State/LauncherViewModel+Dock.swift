// SPDX-License-Identifier: MPL-2.0

import Foundation

extension LauncherViewModel {
	var canRequestDockLaunch: Bool {
		lifecycle.activity == .idle && !lifecycle.refresh.isChecking
	}

	func launchFromDock(region: GameRegion) async -> Bool {
		guard canRequestDockLaunch else { return false }
		await installation.updateInstalledState().value
		guard canRequestDockLaunch, installation.isRegionInstalled(region) else { return false }
		if installation.region != region {
			guard refreshController.selectRegion(region) else { return false }
			await refreshController.waitForCurrentRefresh()
		}
		guard
			installation.region == region,
			installation.isInstalled,
			!installation.isGameUpdateAvailable,
			gameSession.canLaunch
		else { return false }
		launch()
		return gameSession.isGameActive
	}
}
