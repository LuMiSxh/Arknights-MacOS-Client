// SPDX-License-Identifier: MPL-2.0

import CoreGraphics
import Foundation
import ScreenCaptureKit

/// Captures the game window as an image. Tests replace it so they never touch the screen.
protocol WindowImageCapturing: Sendable {
	/// Captures the game window of `processIdentifier` at its native pixel size.
	func captureGameWindow(processIdentifier: Int32) async throws -> CGImage
}

/// Captures through ScreenCaptureKit, which reads the window itself even when another window
/// covers it. `CGWindowListCreateImage` is unavailable at the macOS 15 minimum.
struct ScreenCaptureKitWindowCapturer: WindowImageCapturing {
	func captureGameWindow(processIdentifier: Int32) async throws -> CGImage {
		do {
			let content = try await SCShareableContent.excludingDesktopWindows(
				false, onScreenWindowsOnly: true)
			let windows = Dictionary(
				content.windows.map { ($0.windowID, $0) }, uniquingKeysWith: { first, _ in first })
			let candidates = content.windows.map(Self.candidate)
			guard
				let match = GameWindowLocator.select(candidates, pid: processIdentifier)
					?? GameWindowLocator.selectFallback(candidates, pid: processIdentifier),
				let window = windows[match.windowID]
			else { throw CaptureError.noGameWindow }

			let filter = SCContentFilter(desktopIndependentWindow: window)
			let scale = CGFloat(filter.pointPixelScale)
			let configuration = SCStreamConfiguration()
			configuration.width = Int((filter.contentRect.width * scale).rounded())
			configuration.height = Int((filter.contentRect.height * scale).rounded())
			configuration.showsCursor = false
			configuration.captureResolution = .best
			return try await SCScreenshotManager.captureImage(
				contentFilter: filter, configuration: configuration)
		} catch let error as CaptureError {
			throw error
		} catch {
			throw Self.map(error)
		}
	}

	private static func candidate(_ window: SCWindow) -> GameWindowCandidate {
		GameWindowCandidate(
			windowID: window.windowID,
			ownerProcessIdentifier: window.owningApplication?.processID ?? -1,
			layer: window.windowLayer,
			isOnScreen: window.isOnScreen,
			// ScreenCaptureKit lists only windows macOS draws, and it hides their alpha.
			alpha: 1,
			width: window.frame.width,
			height: window.frame.height)
	}

	private static func map(_ error: any Error) -> CaptureError {
		if (error as NSError).domain == SCStreamErrorDomain,
			(error as NSError).code == SCStreamError.userDeclined.rawValue
		{
			return .permissionDenied
		}
		return .captureFailed(error.localizedDescription)
	}
}
