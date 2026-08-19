// SPDX-License-Identifier: MPL-2.0

import AppKit
import CoreImage
import SwiftUI

/// Unified engine for generating, dynamically tinting, and grid-normalizing macOS application icons.
enum AppIconRenderer {
	/// Insets and centers full-bleed icon artwork onto the standard 80.5% Apple Icon Grid
	/// with transparent margins, matching macOS system apps (Safari, Music, Settings).
	static func padToAppleGrid(image: NSImage) -> NSImage {
		let canvasSize = NSSize(
			width: AppConstants.Icon.canvasDimension,
			height: AppConstants.Icon.canvasDimension
		)
		let contentSize = NSSize(
			width: AppConstants.Icon.squircleDimension,
			height: AppConstants.Icon.squircleDimension
		)
		let origin = NSPoint(
			x: (canvasSize.width - contentSize.width) / 2.0,
			y: (canvasSize.height - contentSize.height) / 2.0
		)
		let drawRect = NSRect(origin: origin, size: contentSize)

		let padded = NSImage(size: canvasSize)
		padded.lockFocus()
		NSGraphicsContext.current?.imageInterpolation = .high
		image.draw(in: drawRect, from: .zero, operation: .copy, fraction: 1.0)
		padded.unlockFocus()
		return padded
	}

	/// Generates a dynamically tinted version of the bundled app icon by shifting the cyan signal layer
	/// to match the target hue in YIQ color space, preserving all Liquid Glass reflections and Apple grid padding.
	static func tintedDefaultIcon(for targetHue: Double) -> NSImage? {
		guard let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
			let baseIcon = NSImage(contentsOf: iconURL),
			let tiffData = baseIcon.tiffRepresentation,
			let ciImage = CIImage(data: tiffData)
		else { return nil }

		let (targetR, targetG, targetB) = rgb(
			hue: targetHue,
			saturation: 1.0,
			brightness: 1.0
		)
		let baseAngle = yiqChromaAngle(red: 0.094, green: 0.82, blue: 1.0)
		let targetAngle = yiqChromaAngle(red: targetR, green: targetG, blue: targetB)
		var deltaAngle = targetAngle - baseAngle
		while deltaAngle > Double.pi { deltaAngle -= 2 * Double.pi }
		while deltaAngle < -Double.pi { deltaAngle += 2 * Double.pi }

		let filter = CIFilter(name: "CIHueAdjust")
		filter?.setValue(ciImage, forKey: kCIInputImageKey)
		filter?.setValue(deltaAngle, forKey: kCIInputAngleKey)

		guard let outputCI = filter?.outputImage else { return nil }
		let context = CIContext(options: [.useSoftwareRenderer: false])
		guard let cgImage = context.createCGImage(outputCI, from: outputCI.extent) else {
			return nil
		}

		let rawTintedImage = NSImage(
			cgImage: cgImage,
			size: NSSize(width: outputCI.extent.width, height: outputCI.extent.height)
		)
		return padToAppleGrid(image: rawTintedImage)
	}

	/// Composites an operator avatar into an authentic Apple-grade macOS squircle app icon:
	/// 1. Native canvas drop shadow.
	/// 2. Dark carbon base plate with dynamic operator ambient glow.
	/// 3. 2.5D character depth cast shadow.
	/// 4. Top-down Liquid Glass specular light curve and 1.5px bevel edge stroke.
	static func createAvatarSquircle(from avatarData: Data) -> NSImage? {
		guard let avatarImage = NSImage(data: avatarData) else { return nil }

		let canvasSize = NSSize(
			width: AppConstants.Icon.canvasDimension,
			height: AppConstants.Icon.canvasDimension
		)
		let squircleRect = standardSquircleRect

		let result = NSImage(size: canvasSize)
		result.lockFocus()
		guard let context = NSGraphicsContext.current?.cgContext else {
			result.unlockFocus()
			return nil
		}
		NSGraphicsContext.current?.imageInterpolation = .high

		let squirclePath = NSBezierPath(
			roundedRect: squircleRect,
			xRadius: AppConstants.Icon.squircleCornerRadius,
			yRadius: AppConstants.Icon.squircleCornerRadius
		)

		// 1. Native macOS Dock Drop Shadow
		context.saveGState()
		let iconShadow = NSShadow()
		iconShadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
		iconShadow.shadowOffset = NSSize(width: 0, height: -6)
		iconShadow.shadowBlurRadius = 12
		iconShadow.set()
		NSColor(calibratedRed: 0.12, green: 0.12, blue: 0.14, alpha: 1.0).setFill()
		squirclePath.fill()
		context.restoreGState()

		// 2. Interior Clipping
		context.saveGState()
		squirclePath.addClip()

		// 2A. Dark Rhodes Island Base Plate
		let bgGradient = NSGradient(
			starting: NSColor(calibratedRed: 0.18, green: 0.19, blue: 0.21, alpha: 1.0),
			ending: NSColor(calibratedRed: 0.07, green: 0.07, blue: 0.08, alpha: 1.0)
		)
		bgGradient?.draw(in: squircleRect, angle: -90)

		// 2B. Dynamic Ambient Glow
		if let ambientColor = sampleDominantColor(from: avatarImage) {
			let glowGradient = NSGradient(
				starting: ambientColor.withAlphaComponent(0.28),
				ending: NSColor.clear
			)
			let centerPoint = NSPoint(x: squircleRect.midX, y: squircleRect.midY + 15)
			glowGradient?.draw(
				fromCenter: centerPoint,
				radius: 10,
				toCenter: centerPoint,
				radius: AppConstants.Icon.squircleDimension * 0.55
			)
		}

		// 3. 2.5D Character Cast Shadow
		context.saveGState()
		let charShadow = NSShadow()
		charShadow.shadowColor = NSColor.black.withAlphaComponent(0.55)
		charShadow.shadowOffset = NSSize(width: 0, height: -4)
		charShadow.shadowBlurRadius = 10
		charShadow.set()

		avatarImage.draw(
			in: squircleRect,
			from: NSRect(origin: .zero, size: avatarImage.size),
			operation: .sourceOver,
			fraction: 1.0
		)
		context.restoreGState()

		// 4. Liquid Glass Top Specular
		let specularGradient = NSGradient(
			starting: NSColor.white.withAlphaComponent(0.20),
			ending: NSColor.white.withAlphaComponent(0.0)
		)
		let specularRect = NSRect(
			x: squircleRect.minX,
			y: squircleRect.minY + AppConstants.Icon.squircleDimension * 0.45,
			width: AppConstants.Icon.squircleDimension,
			height: AppConstants.Icon.squircleDimension * 0.55
		)
		specularGradient?.draw(in: specularRect, angle: -90)

		context.restoreGState()

		// 5. Bevel Stroke
		context.saveGState()
		squirclePath.lineWidth = 1.5
		NSColor.white.withAlphaComponent(0.16).setStroke()
		squirclePath.stroke()
		context.restoreGState()

		result.unlockFocus()
		return result
	}

	private static var standardSquircleRect: NSRect {
		let origin = NSPoint(
			x: (AppConstants.Icon.canvasDimension - AppConstants.Icon.squircleDimension) / 2.0,
			y: (AppConstants.Icon.canvasDimension - AppConstants.Icon.squircleDimension) / 2.0
		)
		return NSRect(
			origin: origin,
			size: NSSize(
				width: AppConstants.Icon.squircleDimension,
				height: AppConstants.Icon.squircleDimension
			)
		)
	}

	private static func yiqChromaAngle(red: Double, green: Double, blue: Double) -> Double {
		let i = 0.596 * red - 0.274 * green - 0.322 * blue
		let q = 0.211 * red - 0.523 * green + 0.312 * blue
		return atan2(q, i)
	}

	private static func sampleDominantColor(from image: NSImage) -> NSColor? {
		guard let tiffData = image.tiffRepresentation,
			let ciImage = CIImage(data: tiffData)
		else { return nil }

		let filter = CIFilter(name: "CIAreaAverage")
		filter?.setValue(ciImage, forKey: kCIInputImageKey)
		filter?.setValue(CIVector(cgRect: ciImage.extent), forKey: kCIInputExtentKey)

		guard let outputImage = filter?.outputImage else { return nil }
		var bitmap = [UInt8](repeating: 0, count: 4)
		let context = CIContext(options: [.useSoftwareRenderer: false])
		context.render(
			outputImage,
			toBitmap: &bitmap,
			rowBytes: 4,
			bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
			format: .RGBA8,
			colorSpace: nil
		)

		let r = CGFloat(bitmap[0]) / 255.0
		let g = CGFloat(bitmap[1]) / 255.0
		let b = CGFloat(bitmap[2]) / 255.0
		let a = CGFloat(bitmap[3]) / 255.0

		guard a > 0.1 else { return nil }
		return NSColor(calibratedRed: r, green: g, blue: b, alpha: 1.0)
	}

	private static func rgb(
		hue: Double,
		saturation: Double,
		brightness: Double
	) -> (Double, Double, Double) {
		let c = brightness * saturation
		let x = c * (1 - abs((hue * 6).truncatingRemainder(dividingBy: 2) - 1))
		let m = brightness - c
		let (r1, g1, b1): (Double, Double, Double)
		switch hue * 6 {
		case 0..<1: (r1, g1, b1) = (c, x, 0)
		case 1..<2: (r1, g1, b1) = (x, c, 0)
		case 2..<3: (r1, g1, b1) = (0, c, x)
		case 3..<4: (r1, g1, b1) = (0, x, c)
		case 4..<5: (r1, g1, b1) = (x, 0, c)
		default: (r1, g1, b1) = (c, 0, x)
		}
		return (r1 + m, g1 + m, b1 + m)
	}
}
