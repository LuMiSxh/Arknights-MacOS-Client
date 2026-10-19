// SPDX-License-Identifier: MPL-2.0

import ArknightsTestSupport
import Darwin
import Foundation
import Testing

@testable import ArknightsGameRuntime

private struct DeduplicationFixture {
	let temporary: TemporaryDirectory
	let root: URL
	let runtimeRoot: URL
	let prefix: URL
	let runtimeLibraries: URL
	let prefixLibraries: URL

	init() throws {
		temporary = try TemporaryDirectory("WinePrefixLibraryDeduplicatorTests")
		root = temporary.url
		runtimeRoot = root.appending(path: "Runtime", directoryHint: .isDirectory)
		prefix = root.appending(path: "Prefix", directoryHint: .isDirectory)
		runtimeLibraries = runtimeRoot.appending(
			path: "lib/wine/x86_64-windows", directoryHint: .isDirectory)
		prefixLibraries = prefix.appending(
			path: "drive_c/windows/system32", directoryHint: .isDirectory)
		try FileManager.default.createDirectory(
			at: runtimeLibraries, withIntermediateDirectories: true)
		try FileManager.default.createDirectory(
			at: prefixLibraries, withIntermediateDirectories: true)
	}

	func write(_ text: String, runtime: String? = nil, prefix name: String? = nil) throws {
		if let runtime {
			try Data(text.utf8).write(to: runtimeLibraries.appending(path: runtime))
		}
		if let name {
			try Data(text.utf8).write(to: prefixLibraries.appending(path: name))
		}
	}

	func inode(_ url: URL) -> UInt64 {
		var info = stat()
		lstat(url.path, &info)
		return UInt64(info.st_ino)
	}

	func remove() {
		temporary.remove()
	}
}

@Test
func deduplicatorLeavesDifferingMissingSymlinkAndExcludedFilesUntouched() throws {
	let fixture = try DeduplicationFixture()
	defer { fixture.remove() }
	try fixture.write("runtime", runtime: "differs.dll")
	try fixture.write("prefix!", prefix: "differs.dll")
	try fixture.write("short", runtime: "sizes.dll")
	try fixture.write("longer text", prefix: "sizes.dll")
	try fixture.write("only in prefix", prefix: "custom.dll")
	try fixture.write("dxmt", runtime: "dxgi.dll", prefix: "dxgi.dll")
	try fixture.write("target", runtime: "linked.dll", prefix: "target.dll")
	try fixture.write("same bytes", runtime: "kernel32.dll", prefix: "kernel32.dll")
	let clonedInode = fixture.inode(fixture.prefixLibraries.appending(path: "kernel32.dll"))
	try FileManager.default.createSymbolicLink(
		at: fixture.prefixLibraries.appending(path: "linked.dll"),
		withDestinationURL: fixture.prefixLibraries.appending(path: "target.dll")
	)
	let dxgiInode = fixture.inode(fixture.prefixLibraries.appending(path: "dxgi.dll"))

	let report = WinePrefixLibraryDeduplicator(excludingNames: ["dxgi.dll"])
		.deduplicate(prefixDirectory: fixture.prefix, runtimeRoot: fixture.runtimeRoot)

	#expect(report.clonedCount == 1)
	#expect(report.clonedBytes == 10)
	#expect(fixture.inode(fixture.prefixLibraries.appending(path: "kernel32.dll")) != clonedInode)
	#expect(report.failures.isEmpty)
	#expect(
		try String(
			contentsOf: fixture.prefixLibraries.appending(path: "differs.dll"), encoding: .utf8)
			== "prefix!")
	#expect(
		try String(
			contentsOf: fixture.prefixLibraries.appending(path: "custom.dll"), encoding: .utf8)
			== "only in prefix")
	#expect(fixture.inode(fixture.prefixLibraries.appending(path: "dxgi.dll")) == dxgiInode)
	let linkTarget = try FileManager.default.destinationOfSymbolicLink(
		atPath: fixture.prefixLibraries.appending(path: "linked.dll").path
	)
	#expect(linkTarget == fixture.prefixLibraries.appending(path: "target.dll").path)

	let unsupported = try DeduplicationFixture()
	defer { unsupported.remove() }
	for name in ["a.dll", "b.dll"] { try unsupported.write("data", runtime: name, prefix: name) }
	let attempts = LockedCounter()
	let stopped = WinePrefixLibraryDeduplicator { _, _ in
		attempts.increment()
		throw POSIXError(.EXDEV)
	}.deduplicate(prefixDirectory: unsupported.prefix, runtimeRoot: unsupported.runtimeRoot)
	#expect(stopped.cloneUnsupportedCode == EXDEV)
	#expect(stopped.clonedCount == 0)
	#expect(attempts.value == 1)

	let failing = try DeduplicationFixture()
	defer { failing.remove() }
	for name in ["a.dll", "b.dll"] { try failing.write("data", runtime: name, prefix: name) }
	let continued = WinePrefixLibraryDeduplicator { source, destination in
		if source.hasSuffix("a.dll") { throw POSIXError(.EACCES) }
		try WinePrefixLibraryDeduplicator.cloneFile(source: source, destination: destination)
	}.deduplicate(prefixDirectory: failing.prefix, runtimeRoot: failing.runtimeRoot)
	#expect(continued.cloneUnsupportedCode == nil)
	#expect(continued.failures.count == 1)
	#expect(continued.clonedCount == 1)
}

private final class LockedCounter: @unchecked Sendable {
	private let lock = NSLock()
	private var count = 0

	var value: Int { lock.withLock { count } }

	func increment() { lock.withLock { count += 1 } }
}
