// SPDX-License-Identifier: MPL-2.0

import CoreGraphics

func makeTestImage() -> CGImage {
	let context = CGContext(
		data: nil, width: 4, height: 4, bitsPerComponent: 8, bytesPerRow: 0,
		space: CGColorSpaceCreateDeviceRGB(),
		bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
	context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
	context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
	return context.makeImage()!
}
