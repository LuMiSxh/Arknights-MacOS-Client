// SPDX-License-Identifier: MPL-2.0

import Foundation

package struct ThemeAccentSnapshot: Equatable, Sendable {
	package let hue: Double
	package let saturation: Double
	package let brightness: Double

	package init(hue: Double, saturation: Double, brightness: Double) {
		self.hue = hue
		self.saturation = saturation
		self.brightness = brightness
	}

	var isValid: Bool {
		(0...1).contains(hue) && (0...1).contains(saturation) && (0...1).contains(brightness)
	}
}
