// SPDX-License-Identifier: MPL-2.0

extension GameRegion {
	var supportRegion: SupportRegion {
		switch self {
		case .global: .global
		case .japan: .japan
		case .korea: .korea
		}
	}
}
