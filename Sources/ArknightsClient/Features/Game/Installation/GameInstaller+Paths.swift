// SPDX-License-Identifier: MPL-2.0

import Foundation

extension GameInstaller {
	func validateManifest(_ manifest: GameManifest, inside installDirectory: URL) throws {
		_ = try Self.safeRelativePath(manifest.source)
		_ = try Self.totalByteCount(of: manifest.file)
		let paths = try manifest.file.map { try Self.safeRelativePath($0.path) }
		var originalPathByKey: [String: String] = [:]

		for (index, path) in paths.enumerated() {
			let key = Self.manifestPathKey(path)
			guard originalPathByKey[key] == nil else {
				throw LauncherError.duplicateManifestPath(manifest.file[index].path)
			}
			originalPathByKey[key] = manifest.file[index].path
		}

		var ownerByInstallerPathKey = [
			Self.manifestPathKey(AppConstants.Game.installedStateFileName):
				AppConstants.Game.installedStateFileName
		]
		for (index, path) in paths.enumerated() {
			let originalPath = manifest.file[index].path
			for installerPath in [path, path + ".part"] {
				let key = Self.manifestPathKey(installerPath)
				if let existingOwner = ownerByInstallerPathKey[key] {
					throw LauncherError.conflictingManifestPaths(existingOwner, originalPath)
				}
				ownerByInstallerPathKey[key] = originalPath
			}
		}

		for child in ownerByInstallerPathKey.keys.sorted() {
			var parent = child
			while let separator = parent.lastIndex(of: "/") {
				parent = String(parent[..<separator])
				if let parentOwner = ownerByInstallerPathKey[parent] {
					throw LauncherError.conflictingManifestPaths(
						parentOwner,
						ownerByInstallerPathKey[child] ?? child
					)
				}
			}
		}

		try assertNoSymbolicLinks(from: installDirectory, through: installDirectory)
		for item in manifest.file {
			let destination = try destinationURL(for: item, inside: installDirectory)
			try assertNoSymbolicLinks(from: installDirectory, through: destination)
			try assertNoSymbolicLinks(
				from: installDirectory,
				through: destination.appendingPathExtension("part")
			)
			try assertSafeExistingPartialFile(at: destination.appendingPathExtension("part"))
		}
	}

	static func totalByteCount(of files: [ManifestFile]) throws -> Int64 {
		var total: Int64 = 0
		for item in files {
			guard item.byteCount <= GameManifest.maximumFileByteCount else {
				throw LauncherError.invalidResponse
			}
			let (sum, overflow) = total.addingReportingOverflow(item.byteCount)
			guard !overflow else { throw LauncherError.invalidResponse }
			total = sum
			guard total <= GameManifest.maximumTotalByteCount else {
				throw LauncherError.invalidResponse
			}
		}
		return total
	}

	func destinationURL(for item: ManifestFile, inside installDirectory: URL) throws -> URL {
		let root = installDirectory.standardizedFileURL
		let destination =
			root.appending(path: try Self.safeRelativePath(item.path)).standardizedFileURL
		guard Self.isContained(destination, in: root) else {
			throw LauncherError.invalidManifestPath(item.path)
		}
		return destination
	}

	static func safeRelativePath(_ input: String) throws -> String {
		let relativeInput = input.hasPrefix("/") ? input.dropFirst() : input[...]
		let components = relativeInput.split(separator: "/", omittingEmptySubsequences: false)
		guard !components.isEmpty,
			components.allSatisfy({ component in
				!component.isEmpty
					&& component != "."
					&& component != ".."
					&& !component.contains("\\")
					&& !component.contains(where: { $0.isNewline || $0.asciiValue == 0 })
			})
		else {
			throw LauncherError.invalidManifestPath(input)
		}
		return components.joined(separator: "/")
	}

	func assertNoSymbolicLinks(from root: URL, through destination: URL) throws {
		let root = root.standardizedFileURL
		let destination = destination.standardizedFileURL
		guard destination == root || Self.isContained(destination, in: root) else {
			throw LauncherError.invalidManifestPath(destination.path)
		}

		let relativePath = String(destination.path.dropFirst(root.path.count))
		let components = relativePath.split(separator: "/").map(String.init)
		var candidate = root
		try rejectSymbolicLink(at: candidate)
		for component in components {
			candidate.append(path: component)
			try rejectSymbolicLink(at: candidate)
		}
	}

	func assertSafeExistingPartialFile(at url: URL) throws {
		do {
			let attributes = try fileManager.attributesOfItem(atPath: url.path)
			let type = attributes[.type] as? FileAttributeType
			let referenceCount = (attributes[.referenceCount] as? NSNumber)?.intValue ?? 1
			guard type == .typeRegular, referenceCount == 1 else {
				throw LauncherError.unsafeInstallerTemporaryFile(url)
			}
		} catch let error as CocoaError
			where error.code == .fileNoSuchFile || error.code == .fileReadNoSuchFile
		{
			return
		}
	}

	private func rejectSymbolicLink(at url: URL) throws {
		do {
			let attributes = try fileManager.attributesOfItem(atPath: url.path)
			if attributes[.type] as? FileAttributeType == .typeSymbolicLink {
				throw LauncherError.symbolicLinkInInstallPath(url)
			}
		} catch let error as CocoaError
			where error.code == .fileNoSuchFile || error.code == .fileReadNoSuchFile
		{
			return
		}
	}

	private static func manifestPathKey(_ path: String) -> String {
		path.precomposedStringWithCanonicalMapping.folding(
			options: [.caseInsensitive],
			locale: Locale(identifier: "en_US_POSIX")
		)
	}

	private static func isContained(_ destination: URL, in root: URL) -> Bool {
		destination.path.hasPrefix(root.path.hasSuffix("/") ? root.path : root.path + "/")
	}
}
