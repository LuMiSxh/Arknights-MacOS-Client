// SPDX-License-Identifier: MPL-2.0

import Foundation

/// Persistable color components used to restore Dynamic Theme before artwork extraction runs.
struct ThemeAccentSnapshot: Equatable, Sendable {
	let hue: Double
	let saturation: Double
	let brightness: Double

	var isValid: Bool {
		(0...1).contains(hue) && (0...1).contains(saturation) && (0...1).contains(brightness)
	}
}
