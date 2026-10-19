// SPDX-License-Identifier: MPL-2.0

import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsGameRuntime

private final class FailingCacheRemovalFileManager: FileManager {
	override func removeItem(at URL: URL) throws {
		throw CocoaError(.fileWriteNoPermission)
	}
}

private func makePrefix(in root: URL, fileManager: FileManager = .default) -> URL {
	let prefix = root.appending(path: "Prefix", directoryHint: .isDirectory)
	let dxmt = prefix.appending(path: "home/.cache/dxmt", directoryHint: .isDirectory)
	let browser = prefix.appending(
		path: "drive_c/users/crossover/AppData/Local/cache", directoryHint: .isDirectory)
	try! fileManager.createDirectory(at: dxmt, withIntermediateDirectories: true)
	try! fileManager.createDirectory(at: browser, withIntermediateDirectories: true)
	try! Data(repeating: 0, count: 10).write(to: dxmt.appending(path: "shaders.db"))
	try! Data(repeating: 0, count: 20).write(to: browser.appending(path: "index"))
	return prefix
}

@Test
func clearRemovesEveryCacheDirectoryButLeavesTheRestOfThePrefix() throws {
	let fileManager = FileManager.default
	let temporary = try TemporaryDirectory("GameCacheCleanerTests")
	defer { temporary.remove() }
	let prefix = makePrefix(in: temporary.url, fileManager: fileManager)
	let caches = try GameCacheCleaner.cacheDirectories(winePrefix: prefix, fileManager: fileManager)
	#expect(caches.count == 2)
	#expect(throws: CocoaError.self) {
		try GameCacheCleaner.clear(
			winePrefix: prefix, fileManager: FailingCacheRemovalFileManager())
	}
	let untouched = prefix.appending(path: "drive_c/windows", directoryHint: .isDirectory)
	try fileManager.createDirectory(at: untouched, withIntermediateDirectories: true)
	let externalUser = prefix.deletingLastPathComponent().appending(
		path: "external-user", directoryHint: .isDirectory)
	let externalCache = externalUser.appending(
		path: "AppData/Local/cache", directoryHint: .isDirectory)
	try fileManager.createDirectory(at: externalCache, withIntermediateDirectories: true)
	let externalFile = externalCache.appending(path: "must-survive")
	try Data(repeating: 0, count: 5).write(to: externalFile)
	let linkedUser = prefix.appending(path: "drive_c/users/linked-user")
	try fileManager.createSymbolicLink(at: linkedUser, withDestinationURL: externalUser)

	try GameCacheCleaner.clear(winePrefix: prefix, fileManager: fileManager)

	#expect(caches.allSatisfy { !fileManager.fileExists(atPath: $0.path) })
	#expect(fileManager.fileExists(atPath: untouched.path))
	#expect(fileManager.fileExists(atPath: externalFile.path))
}
