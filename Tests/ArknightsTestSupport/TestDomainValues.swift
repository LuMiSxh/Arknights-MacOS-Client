// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation

// Values that only tests use, kept out of the production targets.

extension GameDisplaySize {
	package static let quadHD = GameDisplaySize(width: 2560, height: 1440)
}

extension AppPaths {
	package func winePrefix(for region: GameRegion) -> URL {
		winePrefix(for: region.publisher)
	}
}
