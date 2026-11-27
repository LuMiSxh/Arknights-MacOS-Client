// SPDX-License-Identifier: MPL-2.0

import AVFoundation
import ArknightsCore
import CoreMedia
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Checks a custom background video and makes its poster frame. AVFoundation reads the file off
// the main actor; the caller stages and commits the files.
package enum CustomizationVideoIO {
	static let contentTypes: [UTType] = [.mpeg4Movie, .quickTimeMovie]
	private static let supportedCodecs: Set<CMVideoCodecType> = [
		kCMVideoCodecType_H264, kCMVideoCodecType_HEVC,
	]
	private static let posterQuality = 0.9

	// The container names the persisted file, so a switch between containers replaces the old one.
	static func container(of url: URL) -> AppPaths.CustomVideoContainer? {
		guard let type = UTType(filenameExtension: url.pathExtension) else { return nil }
		if type.conforms(to: .mpeg4Movie) { return .mp4 }
		if type.conforms(to: .quickTimeMovie) { return .mov }
		return nil
	}

	package static func isVideo(_ url: URL) -> Bool {
		container(of: url) != nil
	}

	// The poster is the first frame, which is also the frame a paused video shows.
	@concurrent
	static func makePoster(of url: URL) async throws -> Data {
		try await validate(url)
		let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
		generator.appliesPreferredTrackTransform = true
		let (frame, _) = try await generator.image(at: .zero)
		return try jpegData(of: frame, source: url)
	}

	@concurrent
	static func stageVideo(from source: URL, to staged: URL) async throws {
		try FileManager.default.createDirectory(
			at: staged.deletingLastPathComponent(),
			withIntermediateDirectories: true
		)
		try FileManager.default.copyItem(at: source, to: staged)
	}

	private static func validate(_ url: URL) async throws {
		let fileSize = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
		guard fileSize > 0, fileSize <= AppConstants.Artwork.videoMaximumBytes else {
			throw CustomizationError.invalidCustomVideo(url)
		}
		guard let track = try await AVURLAsset(url: url).loadTracks(withMediaType: .video).first
		else { throw CustomizationError.invalidCustomVideo(url) }
		let formats = try await track.load(.formatDescriptions)
		guard
			formats.contains(where: {
				supportedCodecs.contains(CMFormatDescriptionGetMediaSubType($0))
			})
		else { throw CustomizationError.invalidCustomVideo(url) }
	}

	private static func jpegData(of frame: CGImage, source: URL) throws -> Data {
		let output = NSMutableData()
		guard
			let destination = CGImageDestinationCreateWithData(
				output, UTType.jpeg.identifier as CFString, 1, nil)
		else { throw CustomizationError.invalidCustomVideo(source) }
		let options = [kCGImageDestinationLossyCompressionQuality: posterQuality] as CFDictionary
		CGImageDestinationAddImage(destination, frame, options)
		guard CGImageDestinationFinalize(destination) else {
			throw CustomizationError.invalidCustomVideo(source)
		}
		return output as Data
	}
}
