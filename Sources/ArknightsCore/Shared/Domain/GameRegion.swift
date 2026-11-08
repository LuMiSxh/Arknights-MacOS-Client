// SPDX-License-Identifier: MPL-2.0

import Foundation

package enum GamePublisher: String, Codable, Sendable {
	case yostar
	case hypergryph
	case gryphline

	var storageDirectoryName: String {
		switch self {
		case .yostar: "Yostar"
		case .hypergryph: "Hypergryph"
		case .gryphline: "Gryphline"
		}
	}

	package var runtimeLogFileName: String {
		switch self {
		case .yostar: "arknights-yostar.log"
		case .hypergryph: "arknights-hypergryph.log"
		case .gryphline: "arknights-gryphline.log"
		}
	}
}

package enum GameClientVariant: String, Codable, Sendable {
	case standard
	case bilibili
}

struct GameClientProfile: Sendable {
	let publisher: GamePublisher
	let variant: GameClientVariant
	let requiresCanaryPermission: Bool
	let requiresACEWarning: Bool
}

/// The Canary permission that exposes extra regions. This is the single source of truth for
/// whether a region may be selected, installed, listed, or launched. No region needs it now.
package struct RegionAccess: Equatable, Sendable {
	package var canaryFeaturesEnabled: Bool

	package init(canaryFeaturesEnabled: Bool) {
		self.canaryFeaturesEnabled = canaryFeaturesEnabled
	}

	package var selectableRegions: [GameRegion] { GameRegion.allCases.filter(allows) }

	package func allows(_ region: GameRegion) -> Bool {
		guard region.requiresCanaryPermission else { return true }
		return canaryFeaturesEnabled
	}
}

package enum GameRegion: String, CaseIterable, Codable, Sendable, Identifiable {
	case global
	case japan
	case korea
	case taiwan
	case china
	case chinaBilibili

	package static let allCases: [GameRegion] = [
		.global, .japan, .korea, .taiwan, .china, .chinaBilibili,
	]
	package static let yostarCases: [GameRegion] = [.global, .japan, .korea]

	package var id: String { rawValue }

	package var displayName: String {
		switch self {
		case .global: "Global"
		case .japan: "Japan"
		case .korea: "Korea"
		case .taiwan: "Taiwan"
		case .china: "China"
		case .chinaBilibili: "China (Bilibili)"
		}
	}

	/// Server time is a fixed UTC offset, not a named zone, so daylight saving never moves a reset.
	package var serverTimeZone: TimeZone {
		let hoursFromUTC =
			switch self {
			case .global: -7
			case .japan, .korea: 9
			case .taiwan, .china, .chinaBilibili: 8
			}
		return TimeZone(secondsFromGMT: hoursFromUTC * 3600) ?? .gmt
	}

	/// The first 04:00 server reset strictly after `date`.
	package func dailyReset(after date: Date) -> Date {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = serverTimeZone
		var components = calendar.dateComponents([.year, .month, .day], from: date)
		components.hour = 4
		components.minute = 0
		components.second = 0
		guard let todayReset = calendar.date(from: components) else { return date }
		guard todayReset > date else {
			return calendar.date(byAdding: .day, value: 1, to: todayReset) ?? todayReset
		}
		return todayReset
	}

	var clientProfile: GameClientProfile {
		switch self {
		case .global, .japan, .korea:
			GameClientProfile(
				publisher: .yostar,
				variant: .standard,
				requiresCanaryPermission: false,
				requiresACEWarning: false
			)
		case .taiwan:
			GameClientProfile(
				publisher: .gryphline,
				variant: .standard,
				requiresCanaryPermission: false,
				requiresACEWarning: true
			)
		case .china:
			GameClientProfile(
				publisher: .hypergryph,
				variant: .standard,
				requiresCanaryPermission: false,
				requiresACEWarning: true
			)
		case .chinaBilibili:
			GameClientProfile(
				publisher: .hypergryph,
				variant: .bilibili,
				requiresCanaryPermission: false,
				requiresACEWarning: true
			)
		}
	}

	package var publisher: GamePublisher { clientProfile.publisher }

	package var publisherName: String {
		switch publisher {
		case .yostar: "Yostar"
		case .hypergryph: "Hypergryph"
		case .gryphline: "Gryphline"
		}
	}

	package var clientVariant: GameClientVariant { clientProfile.variant }

	package var requiresCanaryPermission: Bool { clientProfile.requiresCanaryPermission }

	/// China servers sign in through the embedded CEF window. Taiwan uses the default browser.
	package var usesEmbeddedLoginWindow: Bool {
		switch self {
		case .china, .chinaBilibili: true
		case .global, .japan, .korea, .taiwan: false
		}
	}

	package var requiresACEWarning: Bool { clientProfile.requiresACEWarning }

	/// Matches the publisher's client identifier where the launcher contract defines one.
	package var gameTag: String {
		switch self {
		case .global: "Arknights_EN"
		case .japan: "Arknights_JP"
		case .korea: "Arknights_KR"
		case .taiwan: "Arknights_TC"
		case .china: "Arknights_CN"
		case .chinaBilibili: "Arknights_CN_Bilibili"
		}
	}

	package var apiBaseURL: URL {
		switch self {
		case .global: Self.yostarAPIURL("https://api-launcher-en.yo-star.com")
		case .japan: Self.yostarAPIURL("https://api-launcher-jp.yo-star.com")
		case .korea: Self.yostarAPIURL("https://api-launcher-kr.yo-star.com")
		case .taiwan, .china, .chinaBilibili:
			preconditionFailure("This region has no Yostar launcher API")
		}
	}

	private static func yostarAPIURL(_ string: String) -> URL {
		guard let url = URL(string: string) else {
			preconditionFailure("Invalid Yostar API base URL: \(string)")
		}
		return url
	}

}
