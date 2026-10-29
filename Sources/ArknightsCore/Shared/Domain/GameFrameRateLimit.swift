// SPDX-License-Identifier: MPL-2.0

/// Frame-rate cap the launcher passes to DXMT. DXMT paces frames from the display refresh rate,
/// so each limit should divide that rate.
package enum GameFrameRateLimit: String, CaseIterable, Codable, Sendable {
	case fps30
	case fps60
	case fps120

	package var displayName: String {
		switch self {
		case .fps30: "30 FPS"
		case .fps60: "60 FPS"
		case .fps120: "120 FPS"
		}
	}

	package var framesPerSecond: Int {
		switch self {
		case .fps30: 30
		case .fps60: 60
		case .fps120: 120
		}
	}
}
