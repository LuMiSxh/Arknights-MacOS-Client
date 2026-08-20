// SPDX-License-Identifier: MPL-2.0

import AppKit

@MainActor
extension AppIconRenderer {
	static func createPresetIcon(
		from avatarData: Data,
		treatment: OperatorIconTreatment,
		accentHue: Double?
	) -> NSImage? {
		guard let avatarImage = NSImage(data: avatarData) else { return nil }
		switch treatment {
		case .launcher:
			return createLauncherIcon(from: avatarImage, accentHue: accentHue)
		case .game:
			return createGameIcon(from: avatarImage, accentHue: accentHue)
		}
	}

	static func createPresetIconPair(
		from avatarData: Data,
		accentHue: Double?
	) -> (launcher: NSImage, game: NSImage)? {
		guard let avatarImage = NSImage(data: avatarData),
			let launcher = createLauncherIcon(from: avatarImage, accentHue: accentHue),
			let game = createGameIcon(from: avatarImage, accentHue: accentHue)
		else { return nil }
		return (launcher, game)
	}

	private static func createGameIcon(
		from avatarImage: NSImage,
		accentHue: Double?
	) -> NSImage? {
		guard let frame = operatorFrame(), let canvas = iconCanvas() else { return nil }
		let (result, context, squirclePath) = canvas
		let rect = standardSquircleRect
		let accent = iconAccentColor(for: accentHue, saturation: 0.9)
		drawIconShadow(path: squirclePath, context: context)

		context.saveGState()
		squirclePath.addClip()
		NSGradient(
			starting: NSColor(calibratedWhite: 0.12, alpha: 1),
			ending: NSColor(calibratedWhite: 0.025, alpha: 1)
		)?.draw(in: rect, angle: -90)
		drawAvatar(avatarImage, in: rect, context: context)
		drawTintedFrame(frame, in: rect, color: accent)
		drawSpecular(in: rect)
		context.restoreGState()
		drawBevel(path: squirclePath, color: accent.withAlphaComponent(0.42))

		result.unlockFocus()
		return result
	}

	private static func operatorFrame() -> NSImage? {
		if let url = Bundle.main.url(forResource: "OperatorIconFrame", withExtension: "svg") {
			return NSImage(contentsOf: url)
		}
		guard
			let url = Bundle.module.url(forResource: "OperatorIconFrame", withExtension: "svg")
		else { return nil }
		return NSImage(contentsOf: url)
	}

	private static func drawTintedFrame(_ frame: NSImage, in rect: NSRect, color: NSColor) {
		let frameRect = rect.insetBy(
			dx: AppConstants.Icon.operatorFrameInset,
			dy: AppConstants.Icon.operatorFrameInset
		)
		let outline = tintedFrame(frame, color: .black)
		let foreground = tintedFrame(frame, color: color)
		let width = AppConstants.Icon.operatorFrameOutlineWidth
		for horizontalOffset in [-width, 0, width] {
			for verticalOffset in [-width, 0, width]
			where horizontalOffset != 0 || verticalOffset != 0 {
				outline.draw(
					in: frameRect.offsetBy(dx: horizontalOffset, dy: verticalOffset),
					from: NSRect(origin: .zero, size: outline.size),
					operation: .sourceOver,
					fraction: 1
				)
			}
		}
		foreground.draw(
			in: frameRect,
			from: NSRect(origin: .zero, size: foreground.size),
			operation: .sourceOver,
			fraction: AppConstants.Icon.operatorFrameOpacity
		)
	}

	private static func tintedFrame(_ frame: NSImage, color: NSColor) -> NSImage {
		let result = NSImage(size: frame.size)
		result.lockFocus()
		frame.draw(
			in: NSRect(origin: .zero, size: frame.size),
			from: NSRect(origin: .zero, size: frame.size),
			operation: .copy,
			fraction: 1
		)
		color.setFill()
		NSRect(origin: .zero, size: frame.size).fill(using: .sourceAtop)
		result.unlockFocus()
		return result
	}

	private static func createLauncherIcon(
		from avatarImage: NSImage,
		accentHue: Double?
	) -> NSImage? {
		guard let canvas = iconCanvas() else { return nil }
		let (result, context, squirclePath) = canvas
		let rect = standardSquircleRect
		let accent = iconAccentColor(for: accentHue, saturation: 0.9)
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

	private static func iconAccentColor(
		for accentHue: Double?,
		saturation: CGFloat
	) -> NSColor {
		NSColor(
			hue: accentHue ?? AppConstants.Icon.baseCyanHue,
			saturation: saturation,
			brightness: 1,
			alpha: 1
		)
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

}
