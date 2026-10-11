// SPDX-License-Identifier: MPL-2.0

import ArknightsCore

enum HomeStrings {

	static func wordmarkFallback(region: GameRegion) -> String {
		switch region {
		case .global: "ARKNIGHTS · GLOBAL"
		case .japan: "ARKNIGHTS · JAPAN"
		case .korea: "ARKNIGHTS · KOREA"
		case .taiwan: "ARKNIGHTS · TAIWAN"
		case .china: "ARKNIGHTS · CHINA"
		case .chinaBilibili: "ARKNIGHTS · CHINA · BILIBILI"
		}
	}

}
