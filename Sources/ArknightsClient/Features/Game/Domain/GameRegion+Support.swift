// SPDX-License-Identifier: MPL-2.0

import Foundation

extension GameRegion {
	var supportRegion: SupportRegion {
		switch self {
		case .global: .global
		case .japan: .japan
		case .korea: .korea
		}
	}
}
