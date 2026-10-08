// SPDX-License-Identifier: MPL-2.0

import Darwin
import Foundation

/// Replaces the builtin PE libraries `wineboot` copies into a prefix with APFS clones of the
/// runtime's identical files, so every prefix stops duplicating hundreds of megabytes.
///
/// Only byte-identical regular files are touched, so DXMT libraries (which intentionally
/// differ) and anything Wine or the game modified are left alone. Each swap clones into a
/// temporary sibling and renames over the destination, so the destination never goes missing.
struct WinePrefixLibraryDeduplicator: Sendable {
	/// Runtime library directory paired with the prefix directory Wine fills from it.
	static let directoryPairs = [
		(runtime: "lib/wine/x86_64-windows", prefix: "drive_c/windows/system32"),
		(runtime: "lib/wine/i386-windows", prefix: "drive_c/windows/syswow64"),
	]

	private static let comparisonChunkBytes = 1 << 20
	private static let cloneUnsupportedCodes: Set<Int32> = [EXDEV, ENOTSUP, EOPNOTSUPP, ENOSYS]

	struct Report: Equatable, Sendable {
		var clonedCount = 0
		var clonedBytes: Int64 = 0
		/// Set when the filesystem cannot clone; deduplication stopped and copies were kept.
		var cloneUnsupportedCode: Int32?
		var failures: [String] = []
	}

	typealias CloneOperation = @Sendable (_ source: String, _ destination: String) throws -> Void

	private let cloneOperation: CloneOperation
	private let excludedNames: Set<String>

	init(
		excludingNames excludedNames: Set<String> = [],
		cloneOperation: @escaping CloneOperation = Self.cloneFile
	) {
		self.excludedNames = excludedNames
		self.cloneOperation = cloneOperation
	}

	static func cloneFile(source: String, destination: String) throws {
		guard clonefile(source, destination, 0) == 0 else {
			throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
		}
	}

	func deduplicate(prefixDirectory: URL, runtimeRoot: URL) -> Report {
		var report = Report()
		for pair in Self.directoryPairs {
			let runtimeDirectory = runtimeRoot.appending(
				path: pair.runtime, directoryHint: .isDirectory)
			let prefixLibraries = prefixDirectory.appending(
				path: pair.prefix, directoryHint: .isDirectory)
			do {
				try deduplicate(prefixLibraries, against: runtimeDirectory, report: &report)
			} catch {
				report.failures.append("\(pair.prefix): \(error.localizedDescription)")
			}
			if report.cloneUnsupportedCode != nil || Task.isCancelled { break }
		}
		return report
	}

	private func deduplicate(_ directory: URL, against runtimeDirectory: URL, report: inout Report)
		throws
	{
		var isDirectory: ObjCBool = false
		guard
			FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory),
			isDirectory.boolValue,
			FileManager.default.fileExists(atPath: runtimeDirectory.path)
		else { return }
		let names = try FileManager.default.contentsOfDirectory(atPath: directory.path)
		for name in names.sorted() where !excludedNames.contains(name) {
			if report.cloneUnsupportedCode != nil || Task.isCancelled { return }
			let destination = directory.appending(path: name)
			let source = runtimeDirectory.appending(path: name)
			do {
				if let size = try replaceableSize(destination: destination, source: source) {
					try replaceWithClone(of: source, at: destination)
					report.clonedCount += 1
					report.clonedBytes += size
				}
			} catch let error as POSIXError
				where Self.cloneUnsupportedCodes.contains(error.code.rawValue)
			{
				report.cloneUnsupportedCode = error.code.rawValue
			} catch {
				report.failures.append("\(name): \(error.localizedDescription)")
			}
		}
	}

	/// Returns the file size when `destination` is a regular file byte-identical to `source`.
	private func replaceableSize(destination: URL, source: URL) throws -> Int64? {
		guard
			let destinationSize = try regularFileSize(destination),
			let sourceSize = try regularFileSize(source),
			destinationSize == sourceSize
		else { return nil }
		return try contentsMatch(destination, source) ? destinationSize : nil
	}

	private func regularFileSize(_ url: URL) throws -> Int64? {
		var info = stat()
		guard lstat(url.path, &info) == 0 else {
			if errno == ENOENT || errno == ENOTDIR { return nil }
			throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
		}
		return (info.st_mode & S_IFMT) == S_IFREG ? Int64(info.st_size) : nil
	}

	private func contentsMatch(_ lhs: URL, _ rhs: URL) throws -> Bool {
		let lhsHandle = try FileHandle(forReadingFrom: lhs)
		let rhsHandle = try FileHandle(forReadingFrom: rhs)
		defer {
			try? lhsHandle.close()
			try? rhsHandle.close()
		}
		while true {
			let lhsChunk = try lhsHandle.read(upToCount: Self.comparisonChunkBytes) ?? Data()
			let rhsChunk = try rhsHandle.read(upToCount: Self.comparisonChunkBytes) ?? Data()
			if lhsChunk != rhsChunk { return false }
			if lhsChunk.isEmpty { return true }
		}
	}

	private func replaceWithClone(of source: URL, at destination: URL) throws {
		let temporary = destination.deletingLastPathComponent()
			.appending(path: ".\(destination.lastPathComponent).clone-\(UUID().uuidString)")
		try cloneOperation(source.path, temporary.path)
		guard rename(temporary.path, destination.path) == 0 else {
			let code = POSIXErrorCode(rawValue: errno) ?? .EIO
			unlink(temporary.path)
			throw POSIXError(code)
		}
	}
}
