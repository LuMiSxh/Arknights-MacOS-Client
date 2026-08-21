// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

private func makePrefix(fileManager: FileManager = .default) -> URL {
	let root = fileManager.temporaryDirectory.appending(
		path: "cache-cleaner-test-\(UUID().uuidString)", directoryHint: .isDirectory)
	let dxmt = root.appending(path: "home/.cache/dxmt", directoryHint: .isDirectory)
	let browser = root.appending(
		path: "drive_c/users/crossover/AppData/Local/cache", directoryHint: .isDirectory)
	try! fileManager.createDirectory(at: dxmt, withIntermediateDirectories: true)
	try! fileManager.createDirectory(at: browser, withIntermediateDirectories: true)
	try! Data(repeating: 0, count: 10).write(to: dxmt.appending(path: "shaders.db"))
	try! Data(repeating: 0, count: 20).write(to: browser.appending(path: "index"))
	return root
}

@Test
func cacheDirectoriesFindsDXMTAndEveryWindowsUserBrowserCache() {
	let fileManager = FileManager.default
	let prefix = makePrefix(fileManager: fileManager)
	defer { try? fileManager.removeItem(at: prefix) }

	let directories = GameCacheCleaner.cacheDirectories(
		winePrefix: prefix, fileManager: fileManager)

	#expect(directories.count == 2)
	#expect(directories.contains { $0.path.hasSuffix("home/.cache/dxmt") })
	#expect(directories.contains { $0.path.hasSuffix("users/crossover/AppData/Local/cache") })
}

@Test
func totalSizeSumsAllCacheDirectories() {
	let fileManager = FileManager.default
	let prefix = makePrefix(fileManager: fileManager)
	defer { try? fileManager.removeItem(at: prefix) }

	#expect(GameCacheCleaner.totalSize(winePrefix: prefix, fileManager: fileManager) == 30)
}

@Test
func clearRemovesEveryCacheDirectoryButLeavesTheRestOfThePrefix() throws {
	let fileManager = FileManager.default
	let prefix = makePrefix(fileManager: fileManager)
	defer { try? fileManager.removeItem(at: prefix) }
	let untouched = prefix.appending(path: "drive_c/windows", directoryHint: .isDirectory)
	try fileManager.createDirectory(at: untouched, withIntermediateDirectories: true)

	try GameCacheCleaner.clear(winePrefix: prefix, fileManager: fileManager)

	#expect(GameCacheCleaner.totalSize(winePrefix: prefix, fileManager: fileManager) == 0)
	#expect(fileManager.fileExists(atPath: untouched.path))
}
