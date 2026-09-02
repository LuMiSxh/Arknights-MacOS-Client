// SPDX-License-Identifier: MPL-2.0

import Foundation

extension LauncherViewModel {
	func selectRegion(_ newRegion: GameRegion) {
		_ = refreshController.selectRegion(newRegion)
	}
}
