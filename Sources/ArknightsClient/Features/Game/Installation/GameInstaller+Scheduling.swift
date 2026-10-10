// SPDX-License-Identifier: MPL-2.0

import ArknightsInfrastructure
import Foundation

extension GameInstaller {
	/// Orders pending downloads so resumable files come first, then larger files.
	///
	/// Files with a non-empty `.part` file (`partialBytes > 0`) lead, so interrupted
	/// downloads finish before new ones start. Remaining ties break by path, then by
	/// input position, which keeps the order deterministic for identical entries.
	static func downloadOrder(
		_ files: [ManifestFile],
		partialBytes: (ManifestFile) throws -> Int64
	) rethrows -> [ManifestFile] {
		let keyed = try files.enumerated().map { offset, file in
			(offset: offset, file: file, hasPartial: try partialBytes(file) > 0)
		}
		return keyed.sorted { lhs, rhs in
			if lhs.hasPartial != rhs.hasPartial { return lhs.hasPartial }
			if lhs.file.byteCount != rhs.file.byteCount {
				return lhs.file.byteCount > rhs.file.byteCount
			}
			if lhs.file.path != rhs.file.path { return lhs.file.path < rhs.file.path }
			return lhs.offset < rhs.offset
		}.map(\.file)
	}

	/// Returns the size of the `.part` file for `item`, or 0 when none exists.
	func partialByteCount(
		of item: ManifestFile,
		in installationRoot: InstallerInstallDirectory
	) throws -> Int64 {
		let relativePath = try Self.safeRelativePath(item.path)
		let destination = try installFile(at: relativePath, inside: installationRoot)
		let partial = destination.sibling(named: destination.name + ".part")
		return try fileSize(at: partial) ?? 0
	}
}
