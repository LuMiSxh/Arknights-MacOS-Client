// SPDX-License-Identifier: MPL-2.0

import Foundation

extension LauncherViewModel {
	func resetArtwork() {
		customization.resetArtwork(
			isDeveloperMode: isDeveloperMode,
			isDownloading: installation.isDownloading,
			restartRefresh: { [weak refreshController] in
				refreshController?.startRefresh()
			}
		)
	}
}
