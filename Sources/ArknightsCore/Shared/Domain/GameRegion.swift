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
	let runtimeEnvironmentOverrides: [String: String]
	let requiresCanaryPermission: Bool
	let requiresACEWarning: Bool
}

/// The Canary permissions that expose extra regions. This is the single source of truth for
/// whether a region may be selected, installed, listed, or launched. Only Taiwan is still gated.
package struct RegionAccess: Equatable, Sendable {
	var canaryFeaturesEnabled: Bool
	var taiwanClientEnabled: Bool

	package init(canaryFeaturesEnabled: Bool, taiwanClientEnabled: Bool) {
		self.canaryFeaturesEnabled = canaryFeaturesEnabled
		self.taiwanClientEnabled = taiwanClientEnabled
	}

	package var selectableRegions: [GameRegion] { GameRegion.allCases.filter(allows) }

	package func allows(_ region: GameRegion) -> Bool {
		guard region.requiresCanaryPermission else { return true }
		guard canaryFeaturesEnabled else { return false }
		if region.requiresTaiwanClientPermission { return taiwanClientEnabled }
		return true
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
	static let generallyAvailableCases: [GameRegion] = yostarCases + [.china, .chinaBilibili]

	var requiresTaiwanClientPermission: Bool {
		self == .taiwan
	}

	package var id: String { rawValue }

	package var displayName: String {
		switch self {
		case .global: "Global"
		case .japan: "Japan"
		case .korea: "Korea"
		case .taiwan: "Taiwan (Canary)"
		case .china: "China"
		case .chinaBilibili: "China (Bilibili)"
		}
	}

	var clientProfile: GameClientProfile {
		switch self {
		case .global, .japan, .korea:
			GameClientProfile(
				publisher: .yostar,
				variant: .standard,
				runtimeEnvironmentOverrides: [:],
				requiresCanaryPermission: false,
				requiresACEWarning: false
			)
		case .taiwan:
			GameClientProfile(
				publisher: .gryphline,
				variant: .standard,
				// Taiwan signs in through the macOS default browser, so it needs no CEF profile.
				runtimeEnvironmentOverrides: [
					AppConstants.Runtime.aceCompactEnvironmentKey: "1"
				],
				requiresCanaryPermission: true,
				requiresACEWarning: true
			)
		case .china:
			GameClientProfile(
				publisher: .hypergryph,
				variant: .standard,
				runtimeEnvironmentOverrides: [
					AppConstants.Runtime.aceCompactEnvironmentKey: "1"
				],
				requiresCanaryPermission: false,
				requiresACEWarning: true
			)
		case .chinaBilibili:
			GameClientProfile(
				publisher: .hypergryph,
				variant: .bilibili,
				runtimeEnvironmentOverrides: [
					AppConstants.Runtime.aceCompactEnvironmentKey: "1",
					AppConstants.Runtime.cefCompatEnvironmentKey: "1",
					AppConstants.Runtime.cnCompatEnvironmentKey: "1",
				],
				requiresCanaryPermission: false,
				requiresACEWarning: true
			)
		}
	}

	package var publisher: GamePublisher { clientProfile.publisher }

	package var clientVariant: GameClientVariant { clientProfile.variant }

	/// Whether the region is hidden until the corresponding canary permission is enabled.
	package var requiresCanaryPermission: Bool { clientProfile.requiresCanaryPermission }

	/// Environment flags selected by this client profile when its game process launches.
	package var runtimeEnvironmentOverrides: [String: String] {
		clientProfile.runtimeEnvironmentOverrides
	}

	/// Whether Play must show the ACE compatibility warning before launching.
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
		case .global: URL(string: "https://api-launcher-en.yo-star.com")!
		case .japan: URL(string: "https://api-launcher-jp.yo-star.com")!
		case .korea: URL(string: "https://api-launcher-kr.yo-star.com")!
		case .taiwan, .china, .chinaBilibili:
			preconditionFailure("This region has no Yostar launcher API")
		}
	}

}
