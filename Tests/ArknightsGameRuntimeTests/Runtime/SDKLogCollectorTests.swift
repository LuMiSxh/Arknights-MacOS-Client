// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsGameRuntime

@Test(arguments: [(GamePublisher.hypergryph, true), (.gryphline, true), (.yostar, false)])
func sdkLogsAreCopiedForNonYostarPublishersOnly(publisher: GamePublisher, copies: Bool) throws {
	let temporary = try TemporaryDirectory("SDKLogCollectorTests")
	defer { temporary.remove() }
	let source = temporary.url.appending(path: "sdklogs", directoryHint: .isDirectory)
	let destination = temporary.url.appending(path: "out", directoryHint: .isDirectory)
	try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
	try Data("sdk".utf8).write(to: source.appending(path: "u8sdk_pc.log"))
	try Data("abcdefghij".utf8).write(to: source.appending(path: "HGWebview.log"))
	try Data("skip".utf8).write(to: source.appending(path: "HGEventLog.log"))

	try SDKLogCollector.collect(
		publisher: publisher, sources: [source], destination: destination, maximumBytes: 4)

	let copied: [String]
	if FileManager.default.fileExists(atPath: destination.path) {
		copied = try FileManager.default.contentsOfDirectory(atPath: destination.path)
	} else {
		copied = []
	}
	#expect(Set(copied) == (copies ? ["u8sdk_pc.log", "HGWebview.log"] : []))
	if copies {
		#expect(
			try Data(contentsOf: destination.appending(path: "u8sdk_pc.log")) == Data("sdk".utf8))
		// The cap keeps the last bytes.
		#expect(
			try Data(contentsOf: destination.appending(path: "HGWebview.log")) == Data("ghij".utf8))
	}
}

/// A report from 2026-11-19 had no SDK logs: the SDK wrote them under the macOS user's profile
/// while the app looked only in `crossover`.
@Test
func sdkLogsAreFoundUnderEveryPrefixUserProfile() throws {
	let temporary = try TemporaryDirectory("SDKLogCollectorTests")
	defer { temporary.remove() }
	let paths = AppPaths(
		applicationSupportDirectory: temporary.url, cachesDirectory: temporary.url,
		libraryDirectory: temporary.url, downloadsDirectory: temporary.url,
		picturesDirectory: temporary.url)
	let prefix = paths.winePrefix(for: .hypergryph, lane: .arm)
	for (user, content) in [("crossover", "old"), ("luca", "new")] {
		let folder = prefix.appending(
			path: "drive_c/users/\(user)/AppData/LocalLow/HyperGryph/Arknights/sdklogs",
			directoryHint: .isDirectory)
		try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
		let file = folder.appending(path: "u8sdk_bilibili_pc.log")
		try Data(content.utf8).write(to: file)
		let modified = Date(timeIntervalSinceNow: user == "luca" ? 0 : -3_600)
		try FileManager.default.setAttributes(
			[.modificationDate: modified], ofItemAtPath: file.path)
	}
	let destination = temporary.url.appending(path: "out", directoryHint: .isDirectory)

	try SDKLogCollector.collect(
		publisher: .hypergryph,
		sources: try paths.sdkLogDirectories(for: .hypergryph, lane: .arm),
		destination: destination)

	#expect(
		try String(
			contentsOf: destination.appending(path: "u8sdk_bilibili_pc.log"), encoding: .utf8)
			== "new")
}
