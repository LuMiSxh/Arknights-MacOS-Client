// SPDX-License-Identifier: MPL-2.0

import AppKit
import ArknightsCore

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
			return createGameIcon(from: avatarImage)
		}
	}

	@concurrent
	static func renderPresetIcons(
		from avatarData: Data,
		accentHue: Double?
	) async -> RenderedIconPair? {
		guard !Task.isCancelled, let avatarImage = NSImage(data: avatarData),
			let launcher = createLauncherIcon(from: avatarImage, accentHue: accentHue),
			let game = createGameIcon(from: avatarImage)
		else { return nil }
		return RenderedIconPair(launcher: launcher, game: game)
	}

	@concurrent
	static func renderPaddedIcon(from data: Data) async -> RenderedIcon? {
		guard !Task.isCancelled, let raw = NSImage(data: data) else { return nil }
		return RenderedIcon(padToAppleGrid(image: raw))
	}

	private static func createGameIcon(from avatarImage: NSImage) -> NSImage? {
		guard let background = gameIconBackground() else { return nil }
		return renderIcon { context, squirclePath in
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
			drawAvatar(
				avatarImage,
				in: rect,
				context: context,
				shadowOpacity: 0.28,
				shadowBlurRadius: 7
			)
			context.restoreGState()
			drawBevel(
				path: squirclePath,
				color: NSColor.white.withAlphaComponent(AppConstants.Icon.gameBevelOpacity)
			)
		}
	}

	private static func gameIconBackground() -> NSImage? {
		bundledImage(.gameIconBackground)
	}

	private static func operatorFrame() -> NSImage? {
		bundledImage(.operatorIconFrame)
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
		let bounds = NSRect(origin: .zero, size: frame.size)
		return RGBABitmap.image(size: frame.size, scale: AppConstants.Icon.renderScale) { _ in
			frame.draw(in: bounds, from: bounds, operation: .copy, fraction: 1)
			color.setFill()
			bounds.fill(using: .sourceAtop)
		} ?? frame
	}

	private static func createLauncherIcon(
		from avatarImage: NSImage,
		accentHue: Double?
	) -> NSImage? {
		guard let frame = operatorFrame() else { return nil }
		return renderIcon { context, squirclePath in
			let rect = standardSquircleRect
			let accent = iconAccentColor(
				for: accentHue,
				saturation: AppConstants.Icon.launcherAccentSaturation
			)
			drawIconShadow(path: squirclePath, context: context)

			context.saveGState()
			squirclePath.addClip()
			let start = AppConstants.Icon.launcherBackgroundStart
			let end = AppConstants.Icon.launcherBackgroundEnd
			NSGradient(
				starting: NSColor(
					calibratedRed: start.red, green: start.green, blue: start.blue, alpha: 1),
				ending: NSColor(calibratedRed: end.red, green: end.green, blue: end.blue, alpha: 1)
			)?.draw(in: rect, angle: -90)
			drawAvatar(
				avatarImage,
				in: rect.insetBy(
					dx: AppConstants.Icon.launcherAvatarInsetX,
					dy: AppConstants.Icon.launcherAvatarInsetY
				),
				context: context
			)
			drawTintedFrame(frame, in: rect, color: accent)
			drawSpecular(in: rect)

			context.restoreGState()
			drawBevel(
				path: squirclePath,
				color: accent.withAlphaComponent(AppConstants.Icon.launcherBevelOpacity)
			)
		}
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

	private static func renderIcon(
		_ draw: (CGContext, NSBezierPath) -> Void
	) -> NSImage? {
		let size = NSSize(
			width: AppConstants.Icon.canvasDimension,
			height: AppConstants.Icon.canvasDimension
		)
		return RGBABitmap.image(size: size, scale: AppConstants.Icon.renderScale) { context in
			context.imageInterpolation = .high
			let path = NSBezierPath(
				roundedRect: standardSquircleRect,
				xRadius: AppConstants.Icon.squircleCornerRadius,
				yRadius: AppConstants.Icon.squircleCornerRadius
			)
			draw(context.cgContext, path)
		}
	}

	private static func drawIconShadow(path: NSBezierPath, context: CGContext) {
		context.saveGState()
		let shadow = NSShadow()
		shadow.shadowColor = NSColor.black.withAlphaComponent(AppConstants.Icon.shadowOpacity)
		shadow.shadowOffset = NSSize(width: 0, height: -AppConstants.Icon.shadowOffset)
		shadow.shadowBlurRadius = AppConstants.Icon.shadowBlurRadius
		shadow.set()
		NSColor(calibratedRed: 0.12, green: 0.12, blue: 0.14, alpha: 1).setFill()
		path.fill()
		context.restoreGState()
	}

	private static func drawAvatar(
		_ image: NSImage,
		in rect: NSRect,
		context: CGContext,
		shadowOpacity: CGFloat = 0.55,
		shadowBlurRadius: CGFloat = 10
	) {
		context.saveGState()
		let shadow = NSShadow()
		shadow.shadowColor = NSColor.black.withAlphaComponent(shadowOpacity)
		shadow.shadowOffset = NSSize(width: 0, height: -4)
		shadow.shadowBlurRadius = shadowBlurRadius
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
		let fraction = AppConstants.Icon.specularHeightFraction
		NSGradient(
			starting: NSColor.white.withAlphaComponent(AppConstants.Icon.specularOpacity),
			ending: NSColor.white.withAlphaComponent(0)
		)?.draw(
			in: NSRect(
				x: rect.minX,
				y: rect.minY + rect.height * (1 - fraction),
				width: rect.width,
				height: rect.height * fraction
			),
			angle: -90
		)
	}

	private static func drawBevel(path: NSBezierPath, color: NSColor) {
		path.lineWidth = AppConstants.Icon.operatorFrameOutlineWidth
		color.setStroke()
		path.stroke()
	}
}
