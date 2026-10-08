// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

private struct CleanerFixture {
	let root = FileManager.default.temporaryDirectory
		.appending(path: "legacy-clean-\(UUID().uuidString)", directoryHint: .isDirectory)
	var runtimeRoot: URL { root.appending(path: "Runtime", directoryHint: .isDirectory) }
	var prefix: URL { root.appending(path: "Prefix", directoryHint: .isDirectory) }
	var syswow64: URL {
		prefix.appending(path: "drive_c/windows/syswow64", directoryHint: .isDirectory)
	}

	init(runtimeShipsI386: Bool) throws {
		let fileManager = FileManager.default
		try fileManager.createDirectory(at: syswow64, withIntermediateDirectories: true)
		try fileManager.createDirectory(
			at: runtimeRoot.appending(path: "lib/wine/x86_64-windows"),
			withIntermediateDirectories: true)
		if runtimeShipsI386 {
			try fileManager.createDirectory(
				at: runtimeRoot.appending(path: "lib/wine/i386-windows"),
				withIntermediateDirectories: true)
		}
	}

	static func peData(marker: String?, padding: Int = 64) -> Data {
		var data = Data("MZ".utf8) + Data(count: 0x3E)
		if let marker { data.append(Data(marker.utf8)) }
		return data + Data(count: padding)
	}

	func write(_ data: Data, _ name: String) throws {
		try data.write(to: syswow64.appending(path: name))
	}

	func exists(_ name: String) -> Bool {
		FileManager.default.fileExists(atPath: syswow64.appending(path: name).path)
	}

	func remove() { try? FileManager.default.removeItem(at: root) }
}

private let cleaner = WinePrefixLegacyLibraryCleaner(
	launcherInstalledNames: Set(WineRuntime.dxmtLibraryNames))

@Test
func cleanerRemovesOnlyWineBuiltinsAndLauncherDXMTLibraries() throws {
	let fixture = try CleanerFixture(runtimeShipsI386: false)
	defer { fixture.remove() }
	try fixture.write(CleanerFixture.peData(marker: "Wine builtin DLL"), "kernel32.dll")
	try fixture.write(CleanerFixture.peData(marker: "Wine builtin DLL"), "notepad.exe")
	try fixture.write(Data("x32-d3d11.dll".utf8), "d3d11.dll")
	try fixture.write(Data("x32-winemetal.dll".utf8), "winemetal.dll")
	try fixture.write(CleanerFixture.peData(marker: nil), "native.dll")
	try fixture.write(CleanerFixture.peData(marker: "Wine placeholder DLL"), "placeholder.dll")
	try fixture.write(Data("Wine builtin DLL".utf8), "text-no-mz.txt")
	try fixture.write(Data("short".utf8), "tiny.dll")
	try FileManager.default.createDirectory(
		at: fixture.syswow64.appending(path: "drivers"), withIntermediateDirectories: true)
	try CleanerFixture.peData(marker: "Wine builtin DLL")
		.write(to: fixture.syswow64.appending(path: "drivers/nested.sys"))

	let report = cleaner.clean(prefixDirectory: fixture.prefix, runtimeRoot: fixture.runtimeRoot)

	#expect(report.removedCount == 4)
	#expect(report.failures.isEmpty)
	for removed in ["kernel32.dll", "notepad.exe", "d3d11.dll", "winemetal.dll"] {
		#expect(!fixture.exists(removed), "\(removed) should be removed")
	}
	for kept in [
		"native.dll", "placeholder.dll", "text-no-mz.txt", "tiny.dll", "drivers/nested.sys",
	] {
		#expect(fixture.exists(kept), "\(kept) should be kept")
	}
}

@Test
func cleanerSkipsWhenTheRuntimeStillShipsI386() throws {
	let fixture = try CleanerFixture(runtimeShipsI386: true)
	defer { fixture.remove() }
	try fixture.write(CleanerFixture.peData(marker: "Wine builtin DLL"), "kernel32.dll")
	try fixture.write(Data("x32-d3d11.dll".utf8), "d3d11.dll")

	let report = cleaner.clean(prefixDirectory: fixture.prefix, runtimeRoot: fixture.runtimeRoot)

	#expect(report.skipped)
	#expect(fixture.exists("kernel32.dll"))
	#expect(fixture.exists("d3d11.dll"))
}

@Test
func cleanerSkipsWhenTheRuntimeRootIsNotARuntime() throws {
	let fixture = try CleanerFixture(runtimeShipsI386: false)
	defer { fixture.remove() }
	try fixture.write(CleanerFixture.peData(marker: "Wine builtin DLL"), "kernel32.dll")

	let report = cleaner.clean(
		prefixDirectory: fixture.prefix,
		runtimeRoot: fixture.root.appending(path: "Missing", directoryHint: .isDirectory))

	#expect(report.skipped)
	#expect(fixture.exists("kernel32.dll"))
}

@Test
func cleanerToleratesAPrefixWithoutSyswow64() throws {
	let fixture = try CleanerFixture(runtimeShipsI386: false)
	defer { fixture.remove() }
	try FileManager.default.removeItem(at: fixture.syswow64)

	let report = cleaner.clean(prefixDirectory: fixture.prefix, runtimeRoot: fixture.runtimeRoot)

	#expect(report == WinePrefixLegacyLibraryCleaner.Report())
}

@Test
func deduplicatorIsHarmlessWhenTheRuntimeHasNoI386Libraries() throws {
	let fixture = try CleanerFixture(runtimeShipsI386: false)
	defer { fixture.remove() }
	try fixture.write(Data("same".utf8), "kernel32.dll")
	let system32 = fixture.prefix.appending(path: "drive_c/windows/system32")
	try FileManager.default.createDirectory(at: system32, withIntermediateDirectories: true)
	try Data("same".utf8).write(to: system32.appending(path: "kernel32.dll"))
	try Data("same".utf8).write(
		to: fixture.runtimeRoot.appending(path: "lib/wine/x86_64-windows/kernel32.dll"))

	let report = WinePrefixLibraryDeduplicator()
		.deduplicate(prefixDirectory: fixture.prefix, runtimeRoot: fixture.runtimeRoot)

	#expect(report.failures.isEmpty)
	#expect(report.clonedCount == 1)
	#expect(
		try Data(contentsOf: fixture.syswow64.appending(path: "kernel32.dll")) == Data("same".utf8))
}
