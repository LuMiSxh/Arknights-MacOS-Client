// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsCustomization

@MainActor
struct CustomArtworkRemovalTests {
	@Test
	func resetRemovesEveryCustomVideoFileAndItsPoster() throws {
		let fixture = try makeCustomizationController()
		defer { fixture.temporary.remove() }
		let files = fixture.paths.customVideoFiles + [fixture.paths.customVideoPoster]
		let directory = fixture.paths.customVideoPoster.deletingLastPathComponent()
		try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
		for file in files {
			try Data("stale".utf8).write(to: file)
		}

		fixture.controller.resetArtwork(isDownloading: true, restartRefresh: {})

		let remaining = files.filter { FileManager.default.fileExists(atPath: $0.path) }
		#expect(remaining.isEmpty)
	}

	@Test
	func aLeftoverVideoDoesNotShadowTheCustomImage() async throws {
		let fixture = try makeCustomizationController()
		defer { fixture.temporary.remove() }
		let directory = fixture.paths.customArtwork.deletingLastPathComponent()
		try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
		let image = try #require(solidImage(.systemRed).tiffRepresentation)
		try image.write(to: fixture.paths.customArtwork)
		try image.write(to: fixture.paths.customVideoPoster)
		try Data("stale".utf8).write(to: fixture.paths.customVideo(.mp4))

		let loaded = await fixture.controller.loadCustomArtwork()

		#expect(loaded)
		guard case .image? = fixture.controller.heroBackground else {
			Issue.record("The leftover video replaced the committed image.")
			return
		}
	}
}
