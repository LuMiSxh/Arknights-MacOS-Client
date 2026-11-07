// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation

/// Runtime behaviors the client enables. A field is false when the runtime omits it.
package struct RuntimeFeatures: Equatable, Sendable, Codable {
	package static let conservative = RuntimeFeatures(
		hardwareCursor: false,
		metalFXSpatialUpscaling: false,
		nativeFullscreenSpace: false
	)

	package let hardwareCursor: Bool
	package let metalFXSpatialUpscaling: Bool
	package let nativeFullscreenSpace: Bool

	package init(
		hardwareCursor: Bool,
		metalFXSpatialUpscaling: Bool,
		nativeFullscreenSpace: Bool
	) {
		self.hardwareCursor = hardwareCursor
		self.metalFXSpatialUpscaling = metalFXSpatialUpscaling
		self.nativeFullscreenSpace = nativeFullscreenSpace
	}

	private enum CodingKeys: String, CodingKey {
		case hardwareCursor
		case metalFXSpatialUpscaling
		case nativeFullscreenSpace
	}

	package init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		hardwareCursor =
			try container.decodeIfPresent(Bool.self, forKey: .hardwareCursor) ?? false
		metalFXSpatialUpscaling =
			try container.decodeIfPresent(Bool.self, forKey: .metalFXSpatialUpscaling) ?? false
		nativeFullscreenSpace =
			try container.decodeIfPresent(Bool.self, forKey: .nativeFullscreenSpace) ?? false
	}

	/// Only fullscreen windows move into a native Space; windowed modes keep the normal window.
	package func usesNativeFullscreenSpace(for displayMode: GameDisplayMode) -> Bool {
		nativeFullscreenSpace && displayMode == .fullscreen
	}

	package func environmentOverrides(
		usesHardwareCursor: Bool,
		displayMode: GameDisplayMode
	) -> [String: String] {
		var overrides: [String: String] = [:]
		if hardwareCursor && usesHardwareCursor {
			overrides[AppConstants.Runtime.hardwareCursorEnvironmentKey] = "1"
		}
		if usesNativeFullscreenSpace(for: displayMode) {
			overrides[AppConstants.Runtime.nativeFullscreenSpaceEnvironmentKey] = "1"
		}
		return overrides
	}
}
