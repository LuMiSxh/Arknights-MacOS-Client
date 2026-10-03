// SPDX-License-Identifier: MPL-2.0

import Foundation

/// The fullscreen resolution a player picked: the display's own size, read at every launch, or a
/// fixed size in game pixels.
enum GameFullscreenResolution: Hashable, Sendable {
	case native
	case fixed(GameDisplaySize)

	/// Stored as "native" or "WIDTHxHEIGHT", like `GameResolution`.
	var storageValue: String {
		switch self {
		case .native: "native"
		case .fixed(let size): "\(size.width)x\(size.height)"
		}
	}

	init?(storageValue: String) {
		if storageValue == "native" {
			self = .native
			return
		}
		let components = storageValue.split(separator: "x")
		guard components.count == 2, let width = Int(components[0]),
			let height = Int(components[1]),
			GameDisplaySize.validDimensions.contains(width),
			GameDisplaySize.validDimensions.contains(height)
		else { return nil }
		self = .fixed(GameDisplaySize(width: width, height: height))
	}

	/// Native first, then sizes between 4K and a larger display's own size, then the official
	/// client's resolutions, each from largest to smallest. Like Displays settings, sizes larger
	/// than the display are left out; they would only cost graphics power.
	static func choices(native: GameDisplaySize?) -> [GameFullscreenResolution] {
		let generated = native.map(generatedSizes(native:)) ?? []
		let official = GameResolution.allCases.map(GameDisplaySize.init)
			.filter { size in native.map(size.fits(in:)) ?? true }
		return [.native] + (generated + official).map(Self.fixed)
	}

	/// Fills the gap between the largest official resolution and a larger display with sizes in
	/// the display's shape, stepping by `generatedResolutionHeightStep` like 1440p, 2160p, 2880p.
	static func generatedSizes(native: GameDisplaySize) -> [GameDisplaySize] {
		let largest = GameDisplaySize(GameResolution.largestOfficial)
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
	init(from decoder: any Decoder) throws {
		let container = try decoder.singleValueContainer()
		let value = try container.decode(String.self)
		guard let resolution = Self(storageValue: value) else {
			throw DecodingError.dataCorruptedError(
				in: container, debugDescription: "Unsupported fullscreen resolution \(value)")
		}
		self = resolution
	}

	func encode(to encoder: any Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(storageValue)
	}
}

extension GameResolution {
	static var largestOfficial: GameResolution {
		allCases.max { $0.width * $0.height < $1.width * $1.height } ?? .ultraHD
	}

	/// The official resolution with the most pixels that fits within `size`.
	static func largest(fitting size: GameDisplaySize) -> GameResolution? {
		allCases
			.filter { GameDisplaySize($0).fits(in: size) }
			.max { $0.width * $0.height < $1.width * $1.height }
	}
}
