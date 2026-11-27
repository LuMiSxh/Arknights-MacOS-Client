// SPDX-License-Identifier: MPL-2.0

import AppKit
import ArknightsCore
import Foundation

extension CustomizationController {
	// The poster is made before anything is staged. Nothing is removed until the new video is
	// committed, so a failed import keeps the previous background.
	func applyCustomVideo(from url: URL, container: AppPaths.CustomVideoContainer) {
		let operationID = beginArtworkMutation()
		Task { [weak self] in
			guard let self else { return }
			defer { self.finishArtworkMutation(operationID) }
			do {
				let poster = try await CustomizationVideoIO.makePoster(of: url)
				guard self.artworkOperationID == operationID else { return }
				await self.commitCustomVideo(
					from: url, container: container, poster: poster, operationID: operationID)
			} catch {
				guard self.artworkOperationID == operationID else { return }
				lifecycle.show(error)
			}
		}
	}

	// An image wins over a video. An image import removes the video files only after it commits,
	// so a leftover video must never shadow the image.
	func persistedVideoURL() -> URL? {
		guard !FileManager.default.fileExists(atPath: paths.customArtwork.path) else { return nil }
		return paths.customVideoFiles.first { FileManager.default.fileExists(atPath: $0.path) }
	}

	func removeCustomVideoFiles() throws {
		for url in paths.customVideoFiles + [paths.customVideoPoster] {
			try CustomizationImageIO.removeIfPresent(url)
		}
	}

	private func commitCustomVideo(
		from source: URL,
		container: AppPaths.CustomVideoContainer,
		poster: Data,
		operationID: UUID
	) async {
		let videoURL = paths.customVideo(container)
		let posterStage = CustomizationImageIO.stagedURL(
			for: paths.customVideoPoster, operationID: operationID)
		let videoStage = CustomizationImageIO.stagedURL(for: videoURL, operationID: operationID)
		let stages = [posterStage, videoStage]
		do {
			let cacheKey = try await CustomizationImageIO.prepareArtwork(
				poster, source: paths.customVideoPoster)
			let decoded = await CustomizationImageIO.decodeImage(poster)
			guard let decoded else { throw CustomizationError.invalidCustomVideo(source) }
			try await dataStager(poster, posterStage)
			try await CustomizationVideoIO.stageVideo(from: source, to: videoStage)
			guard artworkOperationID == operationID else {
				discardVideoStages(stages)
				return
			}
			try CustomizationImageIO.commit(videoStage, to: videoURL)
			try removeSupersededBackground(keeping: videoURL)
			try CustomizationImageIO.commit(posterStage, to: paths.customVideoPoster)
			setHasPersistedCustomArtwork(true)
			setHeroBackground(
				.video(url: videoURL, poster: NSImage(cgImage: decoded, size: .zero)),
				themeCacheKey: cacheKey)
		} catch {
			discardVideoStages(stages)
			guard artworkOperationID == operationID else { return }
			lifecycle.show(error)
		}
	}

	// Removes the other containers and the image after the new video is committed. If a removal
	// fails, the new video is discarded so the previous background stays in place.
	private func removeSupersededBackground(keeping videoURL: URL) throws {
		do {
			for url in paths.customVideoFiles where url != videoURL {
				try CustomizationImageIO.removeIfPresent(url)
			}
			try CustomizationImageIO.removeIfPresent(paths.customArtwork)
		} catch {
			CustomizationImageIO.discard(videoURL, log: log)
			throw error
		}
	}

	private func discardVideoStages(_ stages: [URL]) {
		for stage in stages {
			CustomizationImageIO.discard(stage, log: log)
		}
	}
}
