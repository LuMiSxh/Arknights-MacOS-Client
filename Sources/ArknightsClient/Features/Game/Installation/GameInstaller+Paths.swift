// SPDX-License-Identifier: MPL-2.0

import Darwin
import Foundation

extension GameInstaller {
	func validateManifest(_ manifest: GameManifest, in installDirectory: InstallerInstallDirectory)
		throws
	{
		try validateManifestPaths(manifest)
		for item in manifest.file {
			let path = try Self.safeRelativePath(item.path)
			let destination = try installDirectory.file(at: path, createParents: true)
			try assertRegularDestinationIfPresent(destination)
			let partial = destination.sibling(named: destination.name + ".part")
			try assertSafeExistingPartialFile(at: partial)
		}
	}

	func validateManifestPaths(_ manifest: GameManifest) throws {
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
				AppConstants.Game.installedStateFileName,
			Self.manifestPathKey(AppConstants.Game.installerStagingDirectoryName):
				AppConstants.Game.installerStagingDirectoryName,
		]
		for (index, path) in paths.enumerated() {
			let originalPath = manifest.file[index].path
			if path.split(separator: "/").contains(where: {
				Self.manifestPathKey(String($0))
					== Self.manifestPathKey(AppConstants.Game.installerStagingDirectoryName)
			}) {
				throw LauncherError.conflictingManifestPaths(
					AppConstants.Game.installerStagingDirectoryName,
					originalPath
				)
			}
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

	func assertSafeExistingPartialFile(at partial: InstallerFilePath) throws {
		guard let attributes = try partial.stat() else { return }
		guard attributes.st_mode & S_IFMT == S_IFREG, attributes.st_nlink == 1 else {
			throw LauncherError.unsafeInstallerTemporaryFile(partial.url)
		}
	}

	func assertRegularDestinationIfPresent(_ destination: InstallerFilePath) throws {
		guard let attributes = try destination.stat() else { return }
		guard attributes.st_mode & S_IFMT == S_IFREG else {
			throw LauncherError.unsafeInstallerTemporaryFile(destination.url)
		}
	}

	func installFile(
		at relativePath: String,
		inside installDirectory: InstallerInstallDirectory,
		createParents: Bool = false
	) throws -> InstallerFilePath {
		do {
			return try installDirectory.file(at: relativePath, createParents: createParents)
		} catch {
			throw mapInstallerFileSystemError(error)
		}
	}

	func installDirectory(
		at relativePath: String,
		inside installDirectory: InstallerInstallDirectory,
		createParents: Bool = false
	) throws -> InstallerDirectoryHandle {
		do {
			return try installDirectory.directory(at: relativePath, createParents: createParents)
		} catch {
			throw mapInstallerFileSystemError(error)
		}
	}

	func fileSize(at file: InstallerFilePath) throws -> Int64? {
		guard let attributes = try file.stat() else { return nil }
		guard attributes.st_mode & S_IFMT == S_IFREG, attributes.st_size >= 0 else {
			throw LauncherError.unsafeInstallerTemporaryFile(file.url)
		}
		return Int64(attributes.st_size)
	}

	func mapInstallerFileSystemError(_ error: any Error) -> any Error {
		guard let error = error as? InstallerFileSystemError else { return error }
		return switch error {
		case .invalidPath(let path): LauncherError.invalidManifestPath(path)
		case .symbolicLink(let url): LauncherError.symbolicLinkInInstallPath(url)
		case .unsafeFile(let url), .unsafeDirectory(let url):
			LauncherError.unsafeInstallerTemporaryFile(url)
		case .directoryInUse(let url): LauncherError.installDirectoryInUse(url)
		}
	}

	private static func manifestPathKey(_ path: String) -> String {
		path.precomposedStringWithCanonicalMapping.folding(
			options: [.caseInsensitive],
			locale: Locale(identifier: "en_US_POSIX")
		)
	}

}
