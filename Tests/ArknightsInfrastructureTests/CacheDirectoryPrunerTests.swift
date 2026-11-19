// SPDX-License-Identifier: MPL-2.0

import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsInfrastructure

struct CacheDirectoryPrunerTests {
	@Test
	func evictsTheLeastRecentlyModifiedFilesPastTheLimit() throws {
		let temporary = try TemporaryDirectory("CacheDirectoryPrunerTests")
		defer { temporary.remove() }
		let directory = temporary.url
		let files = [
			("old.cache", Date(timeIntervalSince1970: 1_000)),
			("recent.cache", Date(timeIntervalSince1970: 2_000)),
			("newest.cache", Date(timeIntervalSince1970: 3_000)),
		]
		for (name, date) in files {
			let url = directory.appending(path: name)
			try Data(repeating: 0xAB, count: 8).write(to: url)
			try FileManager.default.setAttributes(
				[.modificationDate: date], ofItemAtPath: url.path)
		}
		let index = directory.appending(path: "index.json")
		try Data("{}".utf8).write(to: index)

		try CacheDirectoryPruner.enforceLimit(
			at: directory,
			maximumBytes: 16,
			preserving: directory.appending(path: "target.cache"),
			pathExtensions: ["cache"]
		)

		#expect(
			!FileManager.default.fileExists(atPath: directory.appending(path: "old.cache").path))
		#expect(
			FileManager.default.fileExists(atPath: directory.appending(path: "recent.cache").path))
		#expect(
			FileManager.default.fileExists(atPath: directory.appending(path: "newest.cache").path))
		#expect(FileManager.default.fileExists(atPath: index.path))
	}

	@Test
	func subdirectoriesAreLeftUntouched() throws {
		let temporary = try TemporaryDirectory("CacheDirectoryPrunerSubdirectoryTests")
		defer { temporary.remove() }
		let directory = temporary.url
		let nested = directory.appending(path: "nested", directoryHint: .isDirectory)
		try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
		let nestedFile = nested.appending(path: "nested.cache")
		try Data(repeating: 0xAB, count: 64).write(to: nestedFile)
		let old = directory.appending(path: "old.cache")
		try Data(repeating: 0xAB, count: 8).write(to: old)

		let failures = try CacheDirectoryPruner.enforceLimit(at: directory, maximumBytes: 0)

		#expect(failures.isEmpty)
		#expect(!FileManager.default.fileExists(atPath: old.path))
		#expect(FileManager.default.fileExists(atPath: nestedFile.path))
	}

	@Test
	func aFileThatCannotBeRemovedIsReportedAndThePruneContinues() throws {
		let temporary = try TemporaryDirectory("CacheDirectoryPrunerFailureTests")
		let directory = temporary.url
		let blocked = directory.appending(path: "blocked.cache")
		let old = directory.appending(path: "old.cache")
		try Data(repeating: 0xAB, count: 8).write(to: blocked)
		try Data(repeating: 0xAB, count: 8).write(to: old)
		try FileManager.default.setAttributes(
			[.modificationDate: Date(timeIntervalSince1970: 1_000)], ofItemAtPath: blocked.path)
		try FileManager.default.setAttributes(
			[.modificationDate: Date(timeIntervalSince1970: 2_000)], ofItemAtPath: old.path)
		// The user immutable flag makes `removeItem` fail with EPERM for the owner.
		try FileManager.default.setAttributes([.immutable: true], ofItemAtPath: blocked.path)
		defer {
			do {
				try FileManager.default.setAttributes(
					[.immutable: false], ofItemAtPath: blocked.path)
			} catch {
				Issue.record("Could not clear the immutable flag: \(error)")
			}
			temporary.remove()
		}

		let failures = try CacheDirectoryPruner.enforceLimit(at: directory, maximumBytes: 8)

		// Directory enumeration resolves the temporary directory's `/var` symlink, so compare names.
		#expect(failures.map(\.url.lastPathComponent) == [blocked.lastPathComponent])
		#expect(FileManager.default.fileExists(atPath: blocked.path))
		#expect(!FileManager.default.fileExists(atPath: old.path))
	}
}
