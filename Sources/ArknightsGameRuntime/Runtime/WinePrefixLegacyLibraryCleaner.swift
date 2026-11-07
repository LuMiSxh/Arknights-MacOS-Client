// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Darwin
import Foundation

// Only regular files that Wine itself generated (PE files carrying Wine's builtin marker in the
// DOS stub) and the DXMT x32 libraries this launcher installed are removed; anything else in
// `syswow64`, including subdirectories, is left alone. Runtimes that still ship
// `lib/wine/i386-windows` are never touched.
struct WinePrefixLegacyLibraryCleaner: Sendable {
	static let runtimeI386Directory = "lib/wine/i386-windows"
	static let prefixDirectory = "drive_c/windows/syswow64"
	// Wine writes this string at offset 0x40 of every builtin DLL it installs into a prefix.
	static let builtinMarker = Data("Wine builtin DLL".utf8)
	static let builtinMarkerOffset = 0x40

	/// The module directory that proves `runtimeRoot` is a real runtime, so a wrong root never
	/// reads as "no i386". The ARM runtime ships `i386-windows`, so it is probed against the native
	/// AArch64 modules while the `runtimeI386Directory` check still forces a skip.
	static func realRuntimeDirectory(for lane: RuntimeLane) -> String {
		switch lane {
		case .x86: "lib/wine/x86_64-windows"
		case .arm: "lib/wine/aarch64-windows"
		}
	}

	struct Report: Equatable, Sendable {
		var skipped = false
		var removedCount = 0
		var removedBytes: Int64 = 0
		var failures: [String] = []
	}

	let launcherInstalledNames: Set<String>

	func clean(prefixDirectory: URL, runtimeRoot: URL, lane: RuntimeLane = .x86) -> Report {
		var report = Report()
		let fileManager = FileManager.default
		guard
			fileManager.fileExists(
				atPath: runtimeRoot.appending(path: Self.realRuntimeDirectory(for: lane)).path),
			!fileManager.fileExists(
				atPath: runtimeRoot.appending(path: Self.runtimeI386Directory).path)
		else {
			report.skipped = true
			return report
		}
		let directory = prefixDirectory.appending(
			path: Self.prefixDirectory, directoryHint: .isDirectory)
		let names: [String]
		do {
			names = try fileManager.contentsOfDirectory(atPath: directory.path)
		} catch {
			if !Self.isMissing(error) { report.failures.append("\(error.localizedDescription)") }
			return report
		}
		for name in names.sorted() {
			if Task.isCancelled { break }
			let file = directory.appending(path: name)
			do {
				guard let size = try regularFileSize(file) else { continue }
				let removable = try launcherInstalledNames.contains(name) || hasBuiltinMarker(file)
				guard removable else { continue }
				try fileManager.removeItem(at: file)
				report.removedCount += 1
				report.removedBytes += size
			} catch {
				report.failures.append("\(name): \(error.localizedDescription)")
			}
		}
		return report
	}

	private func regularFileSize(_ url: URL) throws -> Int64? {
		var info = stat()
		guard lstat(url.path, &info) == 0 else {
			if errno == ENOENT { return nil }
			throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
		}
		return (info.st_mode & S_IFMT) == S_IFREG ? Int64(info.st_size) : nil
	}

	private func hasBuiltinMarker(_ url: URL) throws -> Bool {
		let handle = try FileHandle(forReadingFrom: url)
		let header =
			try handle.read(upToCount: Self.builtinMarkerOffset + Self.builtinMarker.count)
			?? Data()
		try handle.close()
		return header.starts(with: Data("MZ".utf8))
			&& Data(header.dropFirst(Self.builtinMarkerOffset)) == Self.builtinMarker
	}

	private static func isMissing(_ error: Error) -> Bool {
		(error as? CocoaError)?.code == .fileReadNoSuchFile
			|| (error as? CocoaError)?.code == .fileNoSuchFile
			|| (error as? POSIXError)?.code == .ENOENT
	}
}
