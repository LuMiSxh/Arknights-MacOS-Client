// SPDX-License-Identifier: MPL-2.0

import Darwin
import Foundation
import Testing

@testable import ArknightsClient

private struct DeduplicationFixture {
	let root: URL
	let runtimeRoot: URL
	let prefix: URL
	let runtimeLibraries: URL
	let prefixLibraries: URL

	init() throws {
		root = FileManager.default.temporaryDirectory
			.appending(path: "dedup-\(UUID().uuidString)", directoryHint: .isDirectory)
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
		try? FileManager.default.removeItem(at: root)
	}
}

@Test
func deduplicatorReplacesIdenticalLibrariesWithClonesAndKeepsContent() throws {
	let fixture = try DeduplicationFixture()
	defer { fixture.remove() }
	try fixture.write("same bytes", runtime: "kernel32.dll", prefix: "kernel32.dll")
	let destination = fixture.prefixLibraries.appending(path: "kernel32.dll")
	let originalInode = fixture.inode(destination)

	let report = WinePrefixLibraryDeduplicator()
		.deduplicate(prefixDirectory: fixture.prefix, runtimeRoot: fixture.runtimeRoot)

	#expect(report.clonedCount == 1)
	#expect(report.clonedBytes == 10)
	#expect(report.failures.isEmpty)
	#expect(try String(contentsOf: destination, encoding: .utf8) == "same bytes")
	#expect(fixture.inode(destination) != originalInode)
	#expect(
		try FileManager.default.contentsOfDirectory(atPath: fixture.prefixLibraries.path)
			== ["kernel32.dll"]
	)
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
	try FileManager.default.createSymbolicLink(
		at: fixture.prefixLibraries.appending(path: "linked.dll"),
		withDestinationURL: fixture.prefixLibraries.appending(path: "target.dll")
	)
	let dxgiInode = fixture.inode(fixture.prefixLibraries.appending(path: "dxgi.dll"))

	let report = WinePrefixLibraryDeduplicator(excludingNames: ["dxgi.dll"])
		.deduplicate(prefixDirectory: fixture.prefix, runtimeRoot: fixture.runtimeRoot)

	#expect(report.clonedCount == 0)
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
}

@Test
func deduplicatorStopsAndKeepsCopiesWhenCloningIsUnsupported() throws {
	let fixture = try DeduplicationFixture()
	defer { fixture.remove() }
	for name in ["a.dll", "b.dll"] {
		try fixture.write("data", runtime: name, prefix: name)
	}
	let attempts = LockedCounter()

	let report = WinePrefixLibraryDeduplicator { _, _ in
		attempts.increment()
		throw POSIXError(.EXDEV)
	}.deduplicate(prefixDirectory: fixture.prefix, runtimeRoot: fixture.runtimeRoot)

	#expect(report.cloneUnsupportedCode == EXDEV)
	#expect(report.clonedCount == 0)
	#expect(attempts.value == 1)
	for name in ["a.dll", "b.dll"] {
		#expect(
			try String(contentsOf: fixture.prefixLibraries.appending(path: name), encoding: .utf8)
				== "data")
	}
}

@Test
func deduplicatorReportsUnexpectedFailuresAndContinues() throws {
	let fixture = try DeduplicationFixture()
	defer { fixture.remove() }
	for name in ["a.dll", "b.dll"] {
		try fixture.write("data", runtime: name, prefix: name)
	}

	let report = WinePrefixLibraryDeduplicator { source, destination in
		if source.hasSuffix("a.dll") { throw POSIXError(.EACCES) }
		try WinePrefixLibraryDeduplicator.cloneFile(source: source, destination: destination)
	}.deduplicate(prefixDirectory: fixture.prefix, runtimeRoot: fixture.runtimeRoot)

	#expect(report.cloneUnsupportedCode == nil)
	#expect(report.failures.count == 1)
	#expect(report.clonedCount == 1)
	#expect(
		try FileManager.default.contentsOfDirectory(atPath: fixture.prefixLibraries.path).sorted()
			== ["a.dll", "b.dll"]
	)
}

private final class LockedCounter: @unchecked Sendable {
	private let lock = NSLock()
	private var count = 0

	var value: Int { lock.withLock { count } }

	func increment() { lock.withLock { count += 1 } }
}
