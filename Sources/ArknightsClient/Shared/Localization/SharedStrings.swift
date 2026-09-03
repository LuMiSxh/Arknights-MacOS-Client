// SPDX-License-Identifier: MPL-2.0

import Foundation

enum SharedStrings {
	static let done = LocalizedStringResource.sharedActionDone

	static func region(_ region: GameRegion) -> LocalizedStringResource {
		switch region {
		case .global: .sharedRegionGlobal
		case .japan: .sharedRegionJapan
		case .korea: .sharedRegionKorea
		case .china: .sharedRegionChina
		case .chinaBilibili: .sharedRegionChinaBilibili
		}
	}
}
