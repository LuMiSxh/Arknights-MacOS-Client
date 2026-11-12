// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsGameInstallation
@testable import ArknightsGameRuntime

struct RuntimeLoaderIconTests {
	private func iconedBundleNames(
		lane: RuntimeLane, existing: [String], marker: Bool = false
	) throws -> [String] {
		let directory = try TemporaryDirectory("loader-icon")
		defer { directory.remove() }
		for name in existing {
			let bundle = directory.url.appending(path: name, directoryHint: .isDirectory)
			try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
			if marker {
				try Data().write(
					to: URL(filePath: bundle.path + "/" + RuntimeLoaderIcon.markerName))
			}
		}
		let runtime = WineRuntime(
			executableURL: directory.url.appending(path: "bin/Arknights"),
			displayName: "Test",
			revision: "1",
			lane: lane,
			loaderBundleURLs: ["Arknights.app", "wine.app"].map {
				directory.url.appending(path: $0, directoryHint: .isDirectory)
			},
			compatibilityManager: GameCompatibilityManager())
		var applied: [String] = []
		RuntimeLoaderIcon.apply(
			to: runtime, log: LauncherLog(fileURL: directory.url.appending(path: "launcher.log"))
		) { applied.append($0.lastPathComponent) }
		return applied
	}

	@Test
	func iconsTheFirstExistingLoaderBundleOnTheARMLaneOnly() throws {
		#expect(
			try iconedBundleNames(lane: .arm, existing: ["Arknights.app", "wine.app"])
				== ["Arknights.app"])
		#expect(try iconedBundleNames(lane: .arm, existing: ["wine.app"]) == ["wine.app"])
		#expect(try iconedBundleNames(lane: .x86, existing: ["Arknights.app"]).isEmpty)
	}

	@Test
	func skipsABundleThatAlreadyHasAnIcon() throws {
		#expect(
			try iconedBundleNames(lane: .arm, existing: ["Arknights.app"], marker: true).isEmpty)
	}
}
