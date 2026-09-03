// SPDX-License-Identifier: MPL-2.0

import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum CustomizationImageIO {
	static func load(_ url: URL) async throws -> Data {
		try await Task.detached(priority: .userInitiated) {
			let values = try url.resourceValues(forKeys: [
				.fileSizeKey, .totalFileAllocatedSizeKey, .isRegularFileKey,
			])
			guard values.isRegularFile == true else {
				throw LauncherError.invalidCustomImage(url)
			}
			let allocatedSize = values.totalFileAllocatedSize ?? values.fileSize ?? 0
			guard
				allocatedSize > 0,
				allocatedSize <= AppConstants.Artwork.launcherMaximumBytes
			else { throw LauncherError.invalidCustomImage(url) }
			let data = try Data(contentsOf: url, options: .mappedIfSafe)
			try validate(data, source: url)
			return data
		}.value
	}

	static func prepareArtwork(_ data: Data, source: URL) async throws -> String {
		try await Task.detached(priority: .userInitiated) {
			try validate(data, source: source)
			let digest = SHA256.hash(data: data)
			return "custom.\(digest.map { String(format: "%02x", $0) }.joined())"
		}.value
	}

	static func stage(_ data: Data, at url: URL) async throws {
		try await Task.detached(priority: .userInitiated) {
			try FileManager.default.createDirectory(
				at: url.deletingLastPathComponent(),
				withIntermediateDirectories: true
			)
			try data.write(to: url, options: .atomic)
		}.value
	}

	static func stagedURL(for destination: URL, operationID: UUID) -> URL {
		destination.appendingPathExtension("stage.\(operationID.uuidString)")
	}

	static func commit(_ stagedURL: URL, to destination: URL) throws {
		let fileManager = FileManager.default
		if fileManager.fileExists(atPath: destination.path) {
			_ = try fileManager.replaceItemAt(destination, withItemAt: stagedURL)
		} else {
			try fileManager.moveItem(at: stagedURL, to: destination)
		}
	}

	static func discard(_ url: URL, log: LauncherLog) {
		guard FileManager.default.fileExists(atPath: url.path) else { return }
		do {
			try FileManager.default.removeItem(at: url)
		} catch {
			Task { await log.error("Failed to remove staged icon at \(url.path): \(error)") }
		}
	}

	static func removeIfPresent(_ url: URL) throws {
		if FileManager.default.fileExists(atPath: url.path) {
			try FileManager.default.removeItem(at: url)
		}
	}

	static func encodePNG(fromTIFF data: Data) async throws -> Data {
		try await Task.detached(priority: .userInitiated) {
			guard
				let source = CGImageSourceCreateWithData(data as CFData, nil),
				let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
			else { throw LauncherError.cannotEncodeAppIcon }
			let output = NSMutableData()
			guard
				let destination = CGImageDestinationCreateWithData(
					output,
					UTType.png.identifier as CFString,
					1,
					nil
				)
			else { throw LauncherError.cannotEncodeAppIcon }
			CGImageDestinationAddImage(destination, image, nil)
			guard CGImageDestinationFinalize(destination) else {
				throw LauncherError.cannotEncodeAppIcon
			}
			return output as Data
		}.value
	}

	static func validate(_ data: Data, source: URL) throws {
		guard
			!data.isEmpty,
			data.count <= AppConstants.Artwork.launcherMaximumBytes,
			let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
			CGImageSourceGetCount(imageSource) == 1,
			let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil)
				as? [CFString: Any],
			let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
			let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue,
			dimensionsAreSafe(width: width, height: height)
		else { throw LauncherError.invalidCustomImage(source) }
	}

	static func dimensionsAreSafe(width: Int, height: Int) -> Bool {
		width > 0 && height > 0
			&& width <= AppConstants.Artwork.maximumDimension
			&& height <= AppConstants.Artwork.maximumDimension
			&& width <= AppConstants.Artwork.maximumPixels / height
	}
}
