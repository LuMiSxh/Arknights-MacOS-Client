// SPDX-License-Identifier: MPL-2.0

import ArknightsTestSupport
import Foundation

@testable import ArknightsCore

final class FailingMoveFileManager: FileManager {
	private let failingMove: Int
	private var moves = 0
	private(set) var shouldFail = true

	init(failingMove: Int) {
		self.failingMove = failingMove
		super.init()
	}

	func recover() { shouldFail = false }

	override func moveItem(at source: URL, to destination: URL) throws {
		moves += 1
		if shouldFail, moves == failingMove { throw CocoaError(.fileWriteNoPermission) }
		try FileManager.default.moveItem(at: source, to: destination)
	}
}

struct MigrationFixture {
	let temporary: TemporaryDirectory
	let paths: AppPaths
	let selectionStore: RuntimeSelectionStore

	init(_ label: String) throws {
		temporary = try TemporaryDirectory(label)
		paths = AppPaths(
			applicationSupportDirectory: temporary.url.appending(
				path: "Support", directoryHint: .isDirectory),
			cachesDirectory: temporary.url.appending(
				path: "Caches", directoryHint: .isDirectory),
			libraryDirectory: temporary.url.appending(
				path: "Library", directoryHint: .isDirectory),
			runtimeSelection: RuntimeSelection(selected: .x86)
		)
		selectionStore = RuntimeSelectionStore(fileURL: paths.runtimeSelectionFile)
	}

	var support: URL { paths.applicationSupportRoot }

	func legacyGame(_ region: GameRegion) -> URL {
		support.appending(path: legacyGamePath(region), directoryHint: .isDirectory)
	}

	func legacyPrefix(_ publisher: GamePublisher, lane: RuntimeLane) -> URL {
		support.appending(
			path: "\(publisher.storageDirectoryName)/\(lane.prefixDirectoryName)",
			directoryHint: .isDirectory)
	}

	@discardableResult
	func makeDirectory(_ url: URL) throws -> URL {
		try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
		return url
	}

	func write(_ text: String, to url: URL) throws {
		try FileManager.default.createDirectory(
			at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
		try Data(text.utf8).write(to: url)
	}

	func exists(_ url: URL) -> Bool {
		FileManager.default.fileExists(atPath: url.path)
	}
}

func legacyGamePath(_ region: GameRegion) -> String {
	let name =
		switch region {
		case .global: "Global"
		case .japan: "Japan"
		case .korea: "Korea"
		case .taiwan: "Taiwan"
		case .china: "China"
		case .chinaBilibili: "China-Bilibili"
		}
	return "\(region.publisher.storageDirectoryName)/\(name)"
}

func layoutSchema(_ url: URL) throws -> Int? {
	guard FileManager.default.fileExists(atPath: url.path) else { return nil }
	struct Document: Decodable { let schemaVersion: Int }
	return try JSONDecoder().decode(Document.self, from: Data(contentsOf: url)).schemaVersion
}

func layoutLeftoversCleaned(_ url: URL) throws -> Bool? {
	guard FileManager.default.fileExists(atPath: url.path) else { return nil }
	struct Document: Decodable { let leftoversCleaned: Bool? }
	return try JSONDecoder().decode(Document.self, from: Data(contentsOf: url)).leftoversCleaned
}
