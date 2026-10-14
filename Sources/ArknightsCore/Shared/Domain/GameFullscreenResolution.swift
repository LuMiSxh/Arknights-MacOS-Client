// SPDX-License-Identifier: MPL-2.0

import Foundation

/// The fullscreen resolution a player picked: the display's own size, read at every launch, or a
/// fixed size in game pixels.
package enum GameFullscreenResolution: Hashable, Sendable {
	case native
	case fixed(GameDisplaySize)

	/// Stored as "native" or "WIDTHxHEIGHT", like `GameLaunchOptions.resolution`.
	package var storageValue: String {
		switch self {
		case .native: "native"
		case .fixed(let size): size.storageValue
		}
	}

	package init?(storageValue: String) {
		if storageValue == "native" {
			self = .native
		} else if let size = GameDisplaySize(storageValue: storageValue) {
			self = .fixed(size)
		} else {
			return nil
		}
	}

	/// Native first, then sizes between 4K and a larger display's own size, then the official
	/// client's resolutions, each from largest to smallest. Like Displays settings, sizes larger
	/// than the display are left out; they would only cost graphics power.
	package static func choices(native: GameDisplaySize?) -> [GameFullscreenResolution] {
		let generated = native.map(generatedSizes(native:)) ?? []
		let official = GameDisplaySize.officialResolutions
			.filter { size in native.map(size.fits(in:)) ?? true }
		return [.native] + (generated + official).map(Self.fixed)
	}

	/// Fills the gap between the largest official resolution and a larger display with sizes in
	/// the display's shape, stepping by `generatedResolutionHeightStep` like 1440p, 2160p, 2880p.
	static func generatedSizes(native: GameDisplaySize) -> [GameDisplaySize] {
		let largest = GameDisplaySize.ultraHD
		guard native.pixelCount > largest.pixelCount else { return [] }
		let step = AppConstants.Game.generatedResolutionHeightStep
		let aspectRatio = Double(native.width) / Double(native.height)
		return stride(from: largest.height + step, to: native.height, by: step)
			.map { height in
				let width = Int((Double(height) * aspectRatio / 2).rounded()) * 2
				return GameDisplaySize(width: width, height: height)
			}
			.filter { $0.pixelCount > largest.pixelCount }
			.reversed()
	}
}

extension GameFullscreenResolution: Codable {
	package init(from decoder: any Decoder) throws {
		let container = try decoder.singleValueContainer()
		let value = try container.decode(String.self)
		guard let resolution = Self(storageValue: value) else {
			throw DecodingError.dataCorruptedError(
				in: container, debugDescription: "Unsupported fullscreen resolution \(value)")
		}
		self = resolution
	}

	package func encode(to encoder: any Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(storageValue)
	}
}
