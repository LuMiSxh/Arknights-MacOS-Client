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
		hardwareCursor = try container.decode(Bool.self, forKey: .hardwareCursor)
		metalFXSpatialUpscaling =
			try container.decode(Bool.self, forKey: .metalFXSpatialUpscaling)
		nativeFullscreenSpace =
			try container.decode(Bool.self, forKey: .nativeFullscreenSpace)
	}

	/// Only fullscreen windows move into a native Space; windowed modes keep the normal window.
	package func usesNativeFullscreenSpace(for displayMode: GameDisplayMode) -> Bool {
		nativeFullscreenSpace && displayMode == .fullscreen
	}

}
