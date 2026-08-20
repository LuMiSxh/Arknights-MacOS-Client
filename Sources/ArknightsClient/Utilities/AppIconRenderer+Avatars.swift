// SPDX-License-Identifier: MPL-2.0

import AppKit
import CoreImage

extension AppIconRenderer {
	static func createAvatarIcon(
		from avatarData: Data,
		style: AvatarIconStyle,
		accentHue: Double?
	) -> NSImage? {
		guard let avatarImage = NSImage(data: avatarData) else { return nil }
		switch style {
		case .rhodesDark:
			return createRhodesDarkIcon(from: avatarImage)
		case .launcherGlass:
			return createLauncherGlassIcon(from: avatarImage, accentHue: accentHue)
		case .gameIcon:
			return createGameIcon(from: avatarImage)
		}
	}

	private static func createRhodesDarkIcon(from avatarImage: NSImage) -> NSImage? {
		guard let canvas = iconCanvas() else { return nil }
		let (result, context, squirclePath) = canvas
		drawIconShadow(path: squirclePath, context: context)

		context.saveGState()
		squirclePath.addClip()
		NSGradient(
			starting: NSColor(calibratedRed: 0.18, green: 0.19, blue: 0.21, alpha: 1),
			ending: NSColor(calibratedRed: 0.07, green: 0.07, blue: 0.08, alpha: 1)
		)?.draw(in: standardSquircleRect, angle: -90)
		if let ambientColor = sampleDominantColor(from: avatarImage) {
			let center = NSPoint(
				x: standardSquircleRect.midX,
				y: standardSquircleRect.midY + 15
			)
			NSGradient(
				starting: ambientColor.withAlphaComponent(0.28),
				ending: .clear
			)?.draw(
				fromCenter: center,
				radius: 10,
				toCenter: center,
				radius: AppConstants.Icon.squircleDimension * 0.55
			)
		}
		drawAvatar(avatarImage, in: standardSquircleRect, context: context)
		drawSpecular(in: standardSquircleRect)
		context.restoreGState()
		drawBevel(path: squirclePath, color: .white.withAlphaComponent(0.16))

		result.unlockFocus()
		return result
	}

	private static func createGameIcon(from avatarImage: NSImage) -> NSImage? {
		guard let background = gameIconBackground(), let canvas = iconCanvas() else {
			return nil
		}
		let (result, context, squirclePath) = canvas
		let rect = standardSquircleRect
		drawIconShadow(path: squirclePath, context: context)

		context.saveGState()
		squirclePath.addClip()
		background.draw(
			in: rect,
			from: NSRect(origin: .zero, size: background.size),
			operation: .copy,
			fraction: 1
		)
		drawAvatar(avatarImage, in: rect, context: context)
		drawSpecular(in: rect)
		context.restoreGState()
		drawBevel(
			path: squirclePath,
			color: NSColor(calibratedRed: 0.05, green: 0.82, blue: 1, alpha: 0.55)
		)

		result.unlockFocus()
		return result
	}

	private static func gameIconBackground() -> NSImage? {
		if let url = Bundle.main.url(
			forResource: "GameIconBackground",
			withExtension: "png"
		) {
			return NSImage(contentsOf: url)
		}
		guard
			let url = Bundle.module.url(
				forResource: "GameIconBackground",
				withExtension: "png"
			)
		else { return nil }
		return NSImage(contentsOf: url)
	}

	private static func createLauncherGlassIcon(
		from avatarImage: NSImage,
		accentHue: Double?
	) -> NSImage? {
		guard let canvas = iconCanvas() else { return nil }
		let (result, context, squirclePath) = canvas
		let rect = standardSquircleRect
		let accent = NSColor(
			hue: accentHue ?? AppConstants.Icon.baseCyanHue,
			saturation: 0.9,
			brightness: 1,
			alpha: 1
		)
		drawIconShadow(path: squirclePath, context: context)

		context.saveGState()
		squirclePath.addClip()
		NSGradient(
			starting: NSColor(calibratedRed: 0.035, green: 0.055, blue: 0.065, alpha: 1),
			ending: NSColor(calibratedRed: 0.035, green: 0.11, blue: 0.16, alpha: 1)
		)?.draw(in: rect, angle: -90)

		let signal = NSBezierPath()
		signal.move(to: NSPoint(x: rect.minX, y: rect.maxY))
		signal.line(to: NSPoint(x: rect.minX + rect.width * 0.34, y: rect.maxY))
		signal.line(to: NSPoint(x: rect.minX + rect.width * 0.18, y: rect.maxY - 72))
		signal.line(to: NSPoint(x: rect.minX, y: rect.maxY - 72))
		signal.close()
		accent.withAlphaComponent(0.92).setFill()
		signal.fill()

		let facet = NSBezierPath()
		facet.move(to: NSPoint(x: rect.maxX - 92, y: rect.maxY))
		facet.line(to: NSPoint(x: rect.maxX, y: rect.maxY))
		facet.line(to: NSPoint(x: rect.maxX, y: rect.maxY - 88))
		facet.close()
		NSColor.white.withAlphaComponent(0.12).setFill()
		facet.fill()

		let glowCenter = NSPoint(x: rect.midX, y: rect.midY + 35)
		NSGradient(
			starting: accent.withAlphaComponent(0.22),
			ending: .clear
		)?.draw(
			fromCenter: glowCenter,
			radius: 8,
			toCenter: glowCenter,
			radius: rect.width * 0.6
		)
		drawAvatar(avatarImage, in: rect.insetBy(dx: 18, dy: 12), context: context)
		drawSpecular(in: rect)

		context.restoreGState()
		drawBevel(path: squirclePath, color: accent.withAlphaComponent(0.42))

		result.unlockFocus()
		return result
	}

	private static var standardSquircleRect: NSRect {
		let inset =
			(AppConstants.Icon.canvasDimension - AppConstants.Icon.squircleDimension) / 2
		return NSRect(
			x: inset,
			y: inset,
			width: AppConstants.Icon.squircleDimension,
			height: AppConstants.Icon.squircleDimension
		)
	}

	private static func iconCanvas() -> (NSImage, CGContext, NSBezierPath)? {
		let size = NSSize(
			width: AppConstants.Icon.canvasDimension,
			height: AppConstants.Icon.canvasDimension
		)
		let result = NSImage(size: size)
		result.lockFocus()
		guard let context = NSGraphicsContext.current?.cgContext else {
			result.unlockFocus()
			return nil
		}
		NSGraphicsContext.current?.imageInterpolation = .high
		let path = NSBezierPath(
			roundedRect: standardSquircleRect,
			xRadius: AppConstants.Icon.squircleCornerRadius,
			yRadius: AppConstants.Icon.squircleCornerRadius
		)
		return (result, context, path)
	}

	private static func drawIconShadow(path: NSBezierPath, context: CGContext) {
		context.saveGState()
		let shadow = NSShadow()
		shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
		shadow.shadowOffset = NSSize(width: 0, height: -6)
		shadow.shadowBlurRadius = 12
		shadow.set()
		NSColor(calibratedRed: 0.12, green: 0.12, blue: 0.14, alpha: 1).setFill()
		path.fill()
		context.restoreGState()
	}

	private static func drawAvatar(_ image: NSImage, in rect: NSRect, context: CGContext) {
		context.saveGState()
		let shadow = NSShadow()
		shadow.shadowColor = NSColor.black.withAlphaComponent(0.55)
		shadow.shadowOffset = NSSize(width: 0, height: -4)
		shadow.shadowBlurRadius = 10
		shadow.set()
		image.draw(
			in: rect,
			from: NSRect(origin: .zero, size: image.size),
			operation: .sourceOver,
			fraction: 1
		)
		context.restoreGState()
	}

	private static func drawSpecular(in rect: NSRect) {
		NSGradient(
			starting: NSColor.white.withAlphaComponent(0.2),
			ending: NSColor.white.withAlphaComponent(0)
		)?.draw(
			in: NSRect(
				x: rect.minX,
				y: rect.minY + rect.height * 0.45,
				width: rect.width,
				height: rect.height * 0.55
			),
			angle: -90
		)
	}

	private static func drawBevel(path: NSBezierPath, color: NSColor) {
		path.lineWidth = 1.5
		color.setStroke()
		path.stroke()
	}

	private static func sampleDominantColor(from image: NSImage) -> NSColor? {
		guard let data = image.tiffRepresentation, let input = CIImage(data: data) else {
			return nil
		}
		let filter = CIFilter(name: "CIAreaAverage")
		filter?.setValue(input, forKey: kCIInputImageKey)
		filter?.setValue(CIVector(cgRect: input.extent), forKey: kCIInputExtentKey)
		guard let output = filter?.outputImage else { return nil }

		var pixel = [UInt8](repeating: 0, count: 4)
		CIContext(options: [.useSoftwareRenderer: false]).render(
			output,
			toBitmap: &pixel,
			rowBytes: 4,
			bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
			format: .RGBA8,
			colorSpace: nil
		)
		guard pixel[3] > 25 else { return nil }
		return NSColor(
			calibratedRed: CGFloat(pixel[0]) / 255,
			green: CGFloat(pixel[1]) / 255,
			blue: CGFloat(pixel[2]) / 255,
			alpha: 1
		)
	}
}
