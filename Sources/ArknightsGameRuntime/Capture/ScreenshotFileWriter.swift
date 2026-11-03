// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Names and writes screenshot files.
enum ScreenshotFileWriter {
	/// `Arknights Global 2026-11-02 at 21.14.05`, the macOS screenshot style without a suffix.
	static func baseName(region: GameRegion, date: Date, timeZone: TimeZone = .current) -> String {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = timeZone
		let parts = calendar.dateComponents(
			[.year, .month, .day, .hour, .minute, .second], from: date)
		let day = String(
			format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
		let time = String(
			format: "%02d.%02d.%02d", parts.hour ?? 0, parts.minute ?? 0, parts.second ?? 0)
		return "Arknights \(region.displayName) \(day) at \(time)"
	}

	/// Encodes `image` as PNG next to its final name, then renames it into place without ever
	/// replacing a file that exists. A taken name gets ` (2)`, ` (3)`, and so on.
	@concurrent
	static func writePNG(_ image: CGImage, to directory: URL, baseName: String) async throws -> URL
	{
		try write(image, to: directory, baseName: baseName)
	}

	static func write(_ image: CGImage, to directory: URL, baseName: String) throws -> URL {
		let fileManager = FileManager.default
		try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
		let partURL = directory.appending(path: ".\(UUID().uuidString).png.part")
		do {
			try encode(image, to: partURL)
			for suffix in 1...AppConstants.Screenshots.maximumNameSuffix {
				let name = suffix == 1 ? baseName : "\(baseName) (\(suffix))"
				let target = directory.appending(path: "\(name).png")
				if try renameWithoutReplacing(partURL, to: target) { return target }
			}
			throw CaptureError.saveFailed("Every file name is taken in \(directory.path).")
		} catch {
			// best effort: the original error matters more than a leftover .part file.
			try? fileManager.removeItem(at: partURL)
			throw error
		}
	}

	private static func encode(_ image: CGImage, to url: URL) throws {
		guard
			let destination = CGImageDestinationCreateWithURL(
				url as CFURL, UTType.png.identifier as CFString, 1, nil)
		else { throw CaptureError.saveFailed("Cannot create \(url.lastPathComponent).") }
		CGImageDestinationAddImage(destination, image, nil)
		guard CGImageDestinationFinalize(destination) else {
			throw CaptureError.saveFailed("Cannot encode the PNG.")
		}
	}

	/// `RENAME_EXCL` fails instead of replacing, which keeps the check and the move atomic.
	/// Returns false when `target` exists.
	private static func renameWithoutReplacing(_ source: URL, to target: URL) throws -> Bool {
		let result = renamex_np(source.path, target.path, UInt32(RENAME_EXCL))
		if result == 0 { return true }
		if errno == EEXIST { return false }
		throw CaptureError.saveFailed(String(cString: strerror(errno)))
	}
}
