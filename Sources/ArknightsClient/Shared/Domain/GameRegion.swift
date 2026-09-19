// SPDX-License-Identifier: MPL-2.0

import Foundation

enum GamePublisher: String, Codable, Sendable {
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

	var runtimeLogFileName: String {
		switch self {
		case .yostar: "arknights-yostar.log"
		case .hypergryph: "arknights-hypergryph.log"
		case .gryphline: "arknights-gryphline.log"
		}
	}
}

enum GameClientVariant: String, Codable, Sendable {
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

enum GameRegion: String, CaseIterable, Codable, Sendable, Identifiable {
	case global
	case japan
	case korea
	case taiwan
	case china
	case chinaBilibili

	static let allCases: [GameRegion] = [
		.global, .japan, .korea, .taiwan, .china, .chinaBilibili,
	]
	static let yostarCases: [GameRegion] = [.global, .japan, .korea]
	static let canaryCases: [GameRegion] = yostarCases + [.taiwan]

	var requiresChinaClientPermission: Bool {
		switch self {
		case .china, .chinaBilibili: true
		case .global, .japan, .korea, .taiwan: false
		}
	}

	var requiresTaiwanClientPermission: Bool {
		self == .taiwan
	}

	static func selectableCases(
		canaryEnabled: Bool,
		chinaClientsEnabled: Bool,
		taiwanClientEnabled: Bool
	) -> [GameRegion] {
		guard canaryEnabled else { return yostarCases }
		return allCases.filter { region in
			switch region {
			case .taiwan: taiwanClientEnabled
			case .china, .chinaBilibili: chinaClientsEnabled
			case .global, .japan, .korea: true
			}
		}
	}

	var id: String { rawValue }

	var displayName: String {
		switch self {
		case .global: "Global"
		case .japan: "Japan"
		case .korea: "Korea"
		case .taiwan: "Taiwan (Canary)"
		case .china: "China (Canary)"
		case .chinaBilibili: "China — Bilibili (Canary)"
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
				runtimeEnvironmentOverrides: ["ARKNIGHTS_RUNTIME_ACE_COMPACT": "1"],
				requiresCanaryPermission: true,
				requiresACEWarning: true
			)
		case .china:
			GameClientProfile(
				publisher: .hypergryph,
				variant: .standard,
				runtimeEnvironmentOverrides: ["ARKNIGHTS_RUNTIME_ACE_COMPACT": "1"],
				requiresCanaryPermission: true,
				requiresACEWarning: true
			)
		case .chinaBilibili:
			GameClientProfile(
				publisher: .hypergryph,
				variant: .bilibili,
				runtimeEnvironmentOverrides: [
					"ARKNIGHTS_RUNTIME_ACE_COMPACT": "1",
					"ARKNIGHTS_RUNTIME_CN_COMPAT": "1",
				],
				requiresCanaryPermission: true,
				requiresACEWarning: true
			)
		}
	}

	var publisher: GamePublisher { clientProfile.publisher }

	var clientVariant: GameClientVariant { clientProfile.variant }

	/// Whether the region is hidden until the corresponding canary permission is enabled.
	var requiresCanaryPermission: Bool { clientProfile.requiresCanaryPermission }

	/// Environment flags selected by this client profile when its game process launches.
	var runtimeEnvironmentOverrides: [String: String] {
		clientProfile.runtimeEnvironmentOverrides
	}

	/// Whether Play must show the ACE compatibility warning before launching.
	var requiresACEWarning: Bool { clientProfile.requiresACEWarning }

	/// Matches the publisher's client identifier where the launcher contract defines one.
	var gameTag: String {
		switch self {
		case .global: "Arknights_EN"
		case .japan: "Arknights_JP"
		case .korea: "Arknights_KR"
		case .taiwan: "Arknights_TC"
		case .china: "Arknights_CN"
		case .chinaBilibili: "Arknights_CN_Bilibili"
		}
	}

	var apiBaseURL: URL {
		switch self {
		case .global: URL(string: "https://api-launcher-en.yo-star.com")!
		case .japan: URL(string: "https://api-launcher-jp.yo-star.com")!
		case .korea: URL(string: "https://api-launcher-kr.yo-star.com")!
		case .taiwan, .china, .chinaBilibili:
			preconditionFailure("This region has no Yostar launcher API")
		}
	}

}
