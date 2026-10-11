// SPDX-License-Identifier: MPL-2.0

import Darwin
import Foundation

package enum InstallerFileSystemError: Error, Sendable {
	case invalidPath(String)
	case symbolicLink(URL)
	case directoryInUse(URL)
}

/// The install root, or a directory inside it. Every operation resolves a path again and rejects
/// a symbolic link in any component. ``InstallLease`` owns the cross-process lock.
package struct InstallerDirectory: Sendable {
	package let url: URL

	init(at url: URL) {
		self.url = url.standardizedFileURL
	}

	package func file(named name: String) -> InstallerFile {
		InstallerFile(url: url.appending(path: name))
	}

	/// Resolves a manifest-relative path. `createParents` makes missing parent directories.
	package func file(at relativePath: String, createParents: Bool = false) throws -> InstallerFile
	{
		let components = relativePath.split(separator: "/", omittingEmptySubsequences: false)
		guard !relativePath.hasPrefix("/"),
			let name = components.last,
			components.allSatisfy({ component in
				!component.isEmpty
					&& component != "."
					&& component != ".."
					&& !component.contains("\\")
					&& !component.contains(where: { $0.isNewline || $0.asciiValue == 0 })
			})
		else { throw InstallerFileSystemError.invalidPath(relativePath) }
		var directory = url
		for component in components.dropLast() {
			directory = directory.appending(path: String(component), directoryHint: .isDirectory)
			try Self.ensureDirectory(at: directory, create: createParents, mode: 0o755)
		}
		return InstallerFile(url: directory.appending(path: String(name)))
	}

	package func stagingDirectory(named name: String) throws -> InstallerDirectory {
		let staging = url.appending(path: name, directoryHint: .isDirectory)
		try Self.ensureDirectory(at: staging, create: true, mode: 0o700)
		return InstallerDirectory(at: staging)
	}

	/// Returns `nil` when nothing exists at `url` and throws when the last component is a link.
	static func status(of url: URL) throws -> stat? {
		var status = stat()
		guard lstat(url.path, &status) == 0 else {
			if errno == ENOENT { return nil }
			throw POSIXError(.init(rawValue: errno) ?? .EIO)
		}
		if status.st_mode & S_IFMT == S_IFLNK { throw InstallerFileSystemError.symbolicLink(url) }
		return status
	}

	private static func ensureDirectory(at url: URL, create: Bool, mode: mode_t) throws {
		if try status(of: url) == nil {
			guard create else { throw POSIXError(.ENOENT) }
			guard mkdir(url.path, mode) == 0 || errno == EEXIST else {
				throw POSIXError(.init(rawValue: errno) ?? .EIO)
			}
		}
		guard let status = try status(of: url), status.st_mode & S_IFMT == S_IFDIR else {
			throw POSIXError(.ENOTDIR)
		}
	}
}

package struct InstallerFile: Sendable {
	package let url: URL

	package var name: String { url.lastPathComponent }

	package func sibling(named name: String) -> InstallerFile {
		InstallerFile(url: url.deletingLastPathComponent().appending(path: name))
	}

	package func open(flags: Int32, mode: mode_t = 0) throws -> Int32 {
		let descriptor = Darwin.open(url.path, flags | O_NONBLOCK, mode)
		guard descriptor >= 0 else {
			if errno == ELOOP { throw InstallerFileSystemError.symbolicLink(url) }
			throw POSIXError(.init(rawValue: errno) ?? .EIO)
		}
		return descriptor
	}

	package func stat() throws -> stat? {
		try InstallerDirectory.status(of: url)
	}

	package func rename(to destination: InstallerFile) throws {
		guard Darwin.rename(url.path, destination.url.path) == 0 else {
			throw POSIXError(.init(rawValue: errno) ?? .EIO)
		}
	}

	package func unlink() throws {
		guard Darwin.unlink(url.path) == 0 || errno == ENOENT else {
			throw POSIXError(.init(rawValue: errno) ?? .EIO)
		}
	}

	/// Flushes the parent directory so a rename into it survives a crash.
	package func synchronizeParent() throws {
		let descriptor = Darwin.open(
			url.deletingLastPathComponent().path, O_RDONLY | O_DIRECTORY | O_CLOEXEC)
		guard descriptor >= 0 else { throw POSIXError(.init(rawValue: errno) ?? .EIO) }
		defer { _ = close(descriptor) }
		guard fsync(descriptor) == 0 else { throw POSIXError(.init(rawValue: errno) ?? .EIO) }
	}
}
