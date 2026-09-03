// SPDX-License-Identifier: MPL-2.0

import CryptoKit
import Foundation
import ImageIO

extension PresetCatalogService {
	func enforceImageCacheLimitIfNeeded() async {
		guard !hasEnforcedImageCacheLimit else { return }
		hasEnforcedImageCacheLimit = true
		do {
			try pruneImageCache(
				incomingBytes: 0,
				preserving: cacheDirectory.appending(path: ".cache-limit-check")
			)
		} catch {
			await log.error(
				"Failed to enforce the preset image cache limit at \(cacheDirectory.path): \(error.localizedDescription)"
			)
		}
	}

	func imageData(for url: URL, cacheKey: String) async throws -> Data {
		await enforceImageCacheLimitIfNeeded()
		let epoch = cacheEpoch
		guard Self.isAllowedRemoteAssetURL(url) else {
			throw LauncherError.invalidRemoteAsset(url)
		}
		let cachedFile = cacheFileURL(for: cacheKey)
		if let data = await cachedImageData(from: cachedFile, epoch: epoch) {
			guard cacheEpoch == epoch else { throw CancellationError() }
			return data
		}

		var candidates = [url]
		if url.host?.lowercased() == "cdn.jsdelivr.net" {
			let filename = url.lastPathComponent
			let fallbackBases = [
				URL(
					string:
						"https://raw.githubusercontent.com/PuppiizSunniiz/Arknight-Images/main/avatars/"
				)!,
				URL(
					string:
						"https://raw.githubusercontent.com/Aceship/Arknight-Images/main/avatars/"
				)!,
			]
			candidates.append(contentsOf: fallbackBases.map { $0.appending(path: filename) })
		}

		var lastError: (any Error)?
		for candidate in candidates {
			for _ in 0..<AppConstants.Presets.imageDownloadAttempts {
				do {
					let data = try await fetchImageData(from: candidate)
					guard cacheEpoch == epoch else { throw CancellationError() }
					await cacheImageData(data, at: cachedFile, epoch: epoch)
					guard cacheEpoch == epoch else { throw CancellationError() }
					return data
				} catch {
					guard cacheEpoch == epoch else { throw CancellationError() }
					if Task.isCancelled { throw CancellationError() }
					lastError = error
				}
			}
		}
		let finalError = lastError ?? LauncherError.invalidPresetImage(url)
		guard cacheEpoch == epoch else { throw CancellationError() }
		await log.error(
			"Failed to load preset image from \(url.absoluteString): \(finalError.localizedDescription)"
		)
		guard cacheEpoch == epoch else { throw CancellationError() }
		throw finalError
	}

	func cacheFileURL(for cacheKey: String) -> URL {
		cacheDirectory.appending(path: Self.cacheFilename(for: cacheKey))
	}

	static func cacheFilename(for cacheKey: String) -> String {
		let digest = SHA256.hash(data: Data(cacheKey.utf8))
		let alphabet = Array("0123456789abcdef")
		let characters = digest.flatMap { byte in
			[alphabet[Int(byte >> 4)], alphabet[Int(byte & 0x0F)]]
		}
		return String(characters) + ".cache"
	}

	private func fetchImageData(from url: URL) async throws -> Data {
		guard Self.isAllowedRemoteAssetURL(url) else {
			throw LauncherError.invalidRemoteAsset(url)
		}
		var request = URLRequest(
			url: url,
			cachePolicy: .reloadIgnoringLocalCacheData,
			timeoutInterval: AppConstants.Presets.requestTimeout
		)
		request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
		let (data, response) = try await loader.data(
			for: request,
			maximumBytes: AppConstants.Presets.imageMaximumBytes
		)
		guard response.statusCode == 200, !data.isEmpty else {
			throw URLError(.badServerResponse)
		}
		try Self.validateImageData(data, source: url)
		return data
	}

	private func cachedImageData(from url: URL, epoch: UInt64) async -> Data? {
		guard FileManager.default.fileExists(atPath: url.path) else { return nil }
		do {
			let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
			guard attributes[.type] as? FileAttributeType == .typeRegular else {
				try FileManager.default.removeItem(at: url)
				await log.error("Removed non-regular preset cache entry at \(url.path)")
				guard cacheEpoch == epoch else { return nil }
				return nil
			}
			let size = (attributes[.size] as? NSNumber)?.intValue ?? 0
			guard size > 0, size <= AppConstants.Presets.imageMaximumBytes else {
				try FileManager.default.removeItem(at: url)
				await log.error(
					"Removed oversized preset cache entry at \(url.path) (\(size) bytes)")
				guard cacheEpoch == epoch else { return nil }
				return nil
			}
			let data = try Self.readBoundedFile(
				at: url,
				maximumBytes: AppConstants.Presets.imageMaximumBytes
			)
			try Self.validateImageData(data, source: url)
			try FileManager.default.setAttributes(
				[.modificationDate: Date.now],
				ofItemAtPath: url.path
			)
			return data
		} catch {
			do {
				if FileManager.default.fileExists(atPath: url.path) {
					try FileManager.default.removeItem(at: url)
				}
			} catch {
				await log.error(
					"Failed to remove invalid preset cache entry at \(url.path): \(error.localizedDescription)"
				)
				guard cacheEpoch == epoch else { return nil }
			}
			await log.error(
				"Rejected preset cache entry at \(url.path): \(error.localizedDescription)")
			guard cacheEpoch == epoch else { return nil }
			return nil
		}
	}

	private func cacheImageData(_ data: Data, at url: URL, epoch: UInt64) async {
		guard cacheEpoch == epoch else { return }
		do {
			try FileManager.default.createDirectory(
				at: cacheDirectory,
				withIntermediateDirectories: true
			)
			try pruneImageCache(incomingBytes: Int64(data.count), preserving: url)
			try data.write(to: url, options: .atomic)
		} catch {
			guard cacheEpoch == epoch else { return }
			await log.error(
				"Failed to cache preset image at \(url.path): \(error.localizedDescription)")
			guard cacheEpoch == epoch else { return }
		}
	}

	private func pruneImageCache(incomingBytes: Int64, preserving target: URL) throws {
		let keys: Set<URLResourceKey> = [
			.fileSizeKey, .contentModificationDateKey, .isRegularFileKey, .isSymbolicLinkKey,
		]
		let urls = try FileManager.default.contentsOfDirectory(
			at: cacheDirectory,
			includingPropertiesForKeys: Array(keys),
			options: [.skipsHiddenFiles]
		)
		var entries: [(url: URL, size: Int64, date: Date)] = []
		var total: Int64 = 0
		for url in urls where url.pathExtension == "cache" && url != target {
			let values = try url.resourceValues(forKeys: keys)
			guard values.isRegularFile == true, values.isSymbolicLink != true else {
				try FileManager.default.removeItem(at: url)
				continue
			}
			let size = Int64(values.fileSize ?? 0)
			total += size
			entries.append((url, size, values.contentModificationDate ?? .distantPast))
		}

		let targetTotal = AppConstants.Presets.imageCacheMaximumBytes - incomingBytes
		for entry in entries.sorted(by: { $0.date < $1.date }) where total > targetTotal {
			try FileManager.default.removeItem(at: entry.url)
			total -= entry.size
		}
	}

	static func validateImageData(_ data: Data, source: URL) throws {
		guard !data.isEmpty,
			data.count <= AppConstants.Presets.imageMaximumBytes,
			hasCompleteFileMarker(data),
			let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
			CGImageSourceGetCount(imageSource) == 1,
			let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil)
				as? [CFString: Any],
			let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
			let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue,
			width > 0,
			height > 0,
			width <= AppConstants.Presets.imageMaximumDimension,
			height <= AppConstants.Presets.imageMaximumDimension,
			width <= AppConstants.Presets.imageMaximumPixels / height
		else {
			throw LauncherError.invalidPresetImage(source)
		}
	}

	private static func hasCompleteFileMarker(_ data: Data) -> Bool {
		if data.starts(with: [0xFF, 0xD8, 0xFF]) {
			return data.suffix(2).elementsEqual([0xFF, 0xD9])
		}
		if data.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) {
			return data.suffix(12).elementsEqual([
				0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
			])
		}
		return true
	}
}
