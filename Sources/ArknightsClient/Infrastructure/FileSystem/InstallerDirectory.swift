// SPDX-License-Identifier: MPL-2.0

import Darwin
import Foundation

enum InstallerFileSystemError: Error, Sendable {
	case invalidPath(String)
	case symbolicLink(URL)
	case unsafeFile(URL)
	case unsafeDirectory(URL)
	case directoryInUse(URL)
}

struct InstallerFileIdentity: Equatable, Sendable {
	let device: dev_t
	let inode: ino_t

	init(_ status: stat) {
		device = status.st_dev
		inode = status.st_ino
	}
}

/// Pins the install root. ``InstallLease`` owns the cross-process lock; the legacy `init(at:)`
/// still locks until deallocation for callers that have not moved to the lease yet.
final class InstallerInstallDirectory: @unchecked Sendable {
	let root: InstallerDirectoryHandle
	private let legacyLockDescriptor: Int32?

	var url: URL { root.url }

	/// Legacy locking initializer; it takes the same lock as ``InstallLease`` on its own descriptor.
	convenience init(at url: URL) throws {
		let root = try Self.pinRoot(at: url)
		let descriptor = try Self.acquireLock(on: root)
		self.init(root: root, legacyLockDescriptor: descriptor)
	}

	/// Pins the root without locking. Used by ``InstallLease``, which owns the lock.
	convenience init(pinningAt url: URL) throws {
		self.init(root: try Self.pinRoot(at: url), legacyLockDescriptor: nil)
	}

	private init(root: InstallerDirectoryHandle, legacyLockDescriptor: Int32?) {
		self.root = root
		self.legacyLockDescriptor = legacyLockDescriptor
	}

	deinit {
		if let legacyLockDescriptor { Self.releaseLock(legacyLockDescriptor) }
	}

	static func releaseLock(_ descriptor: Int32) {
		_ = flock(descriptor, LOCK_UN)
		_ = close(descriptor)
	}

	/// Opens a second descriptor on the root and locks it. `flock` binds to the open file
	/// description, so a second acquire conflicts even inside this process. The identity check
	/// rejects a root path that was swapped between pinning and locking.
	static func acquireLock(on root: InstallerDirectoryHandle) throws -> Int32 {
		let descriptor = open(root.url.path, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
		guard descriptor >= 0 else {
			if errno == ELOOP { throw InstallerFileSystemError.symbolicLink(root.url) }
			throw POSIXError(.init(rawValue: errno) ?? .EIO)
		}
		var lockStatus = stat()
		var rootStatus = stat()
		guard fstat(descriptor, &lockStatus) == 0, fstat(root.descriptor, &rootStatus) == 0 else {
			let error = errno
			_ = close(descriptor)
			throw POSIXError(.init(rawValue: error) ?? .EIO)
		}
		guard InstallerFileIdentity(lockStatus) == InstallerFileIdentity(rootStatus) else {
			_ = close(descriptor)
			throw InstallerFileSystemError.unsafeDirectory(root.url)
		}
		guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
			let error = errno
			_ = close(descriptor)
			if error == EWOULDBLOCK || error == EAGAIN {
				throw InstallerFileSystemError.directoryInUse(root.url)
			}
			throw POSIXError(.init(rawValue: error) ?? .EIO)
		}
		return descriptor
	}

	private static func pinRoot(at url: URL) throws -> InstallerDirectoryHandle {
		try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
		let rootURL = url.standardizedFileURL
		let descriptor = open(
			rootURL.path,
			O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
		)
		guard descriptor >= 0 else {
			if errno == ELOOP { throw InstallerFileSystemError.symbolicLink(rootURL) }
			throw POSIXError(.init(rawValue: errno) ?? .EIO)
		}

		var status = stat()
		let statusResult = fstat(descriptor, &status)
		guard statusResult == 0, status.st_mode & S_IFMT == S_IFDIR else {
			let error = statusResult == 0 ? ENOTDIR : errno
			_ = close(descriptor)
			throw POSIXError(.init(rawValue: error) ?? .ENOTDIR)
		}
		var canonicalPath = [CChar](repeating: 0, count: Int(MAXPATHLEN))
		guard fcntl(descriptor, F_GETPATH, &canonicalPath) == 0 else {
			let error = errno
			_ = close(descriptor)
			throw POSIXError(.init(rawValue: error) ?? .EIO)
		}
		let pathEnd = canonicalPath.firstIndex(of: 0) ?? canonicalPath.endIndex
		let canonicalPathString = String(
			decoding: canonicalPath[..<pathEnd].map { UInt8(bitPattern: $0) },
			as: UTF8.self
		)
		let canonicalURL = URL(fileURLWithPath: canonicalPathString, isDirectory: true)
			.standardizedFileURL
		return InstallerDirectoryHandle(descriptor: descriptor, url: canonicalURL)
	}

	func directory(at relativePath: String, createParents: Bool = false) throws
		-> InstallerDirectoryHandle
	{
		let components = try Self.pathComponents(relativePath)
		var directory = root
		for component in components {
			directory = try directory.openDirectory(named: component, create: createParents)
		}
		return directory
	}

	func file(at relativePath: String, createParents: Bool = false) throws
		-> InstallerFilePath
	{
		let components = try Self.pathComponents(relativePath)
		guard let name = components.last else {
			throw InstallerFileSystemError.invalidPath(relativePath)
		}
		var directory = root
		for component in components.dropLast() {
			directory = try directory.openDirectory(named: component, create: createParents)
		}
		return directory.file(named: name)
	}

	func stagingDirectory(named name: String) throws -> InstallerDirectoryHandle {
		try root.stagingDirectory(named: name)
	}

	fileprivate static func removeExtendedACL(from descriptor: Int32, at url: URL) throws {
		guard let existing = acl_get_fd_np(descriptor, ACL_TYPE_EXTENDED) else {
			let error = errno
			if error == ENOENT { return }
			throw POSIXError(.init(rawValue: error) ?? .EIO)
		}
		_ = acl_free(UnsafeMutableRawPointer(existing))

		guard let empty = acl_init(0) else {
			throw POSIXError(.init(rawValue: errno) ?? .ENOMEM)
		}
		defer { _ = acl_free(UnsafeMutableRawPointer(empty)) }
		guard acl_set_fd_np(descriptor, empty, ACL_TYPE_EXTENDED) == 0 else {
			throw POSIXError(.init(rawValue: errno) ?? .EIO)
		}
		try requireNoExtendedACL(on: descriptor, at: url)
	}

	static func makePrivateRegularFile(_ descriptor: Int32, at url: URL) throws {
		var status = stat()
		guard fstat(descriptor, &status) == 0,
			status.st_mode & S_IFMT == S_IFREG,
			status.st_uid == geteuid(),
			status.st_nlink == 1
		else { throw InstallerFileSystemError.unsafeFile(url) }
		try removeExtendedACL(from: descriptor, at: url)
		guard fchmod(descriptor, S_IRUSR | S_IWUSR) == 0 else {
			throw POSIXError(.init(rawValue: errno) ?? .EIO)
		}
		guard fstat(descriptor, &status) == 0,
			status.st_mode & S_IFMT == S_IFREG,
			status.st_uid == geteuid(),
			status.st_nlink == 1,
			status.st_mode & 0o777 == 0o600
		else { throw InstallerFileSystemError.unsafeFile(url) }
		try requireNoExtendedACL(on: descriptor, at: url)
	}

	static func validateTrustedStateFile(_ descriptor: Int32, at url: URL) throws {
		var status = stat()
		guard fstat(descriptor, &status) == 0,
			status.st_mode & S_IFMT == S_IFREG,
			status.st_uid == geteuid(),
			status.st_nlink == 1,
			status.st_size >= 0,
			status.st_mode & 0o400 != 0,
			status.st_mode & 0o022 == 0
		else { throw InstallerFileSystemError.unsafeFile(url) }
		guard let acl = acl_get_fd_np(descriptor, ACL_TYPE_EXTENDED) else {
			if errno == ENOENT { return }
			throw POSIXError(.init(rawValue: errno) ?? .EIO)
		}
		defer { _ = acl_free(UnsafeMutableRawPointer(acl)) }
		var entry: acl_entry_t?
		guard acl_get_entry(acl, 0, &entry) == -1, errno == ENOENT else {
			throw InstallerFileSystemError.unsafeFile(url)
		}
	}

	fileprivate static func requireNoExtendedACL(on descriptor: Int32, at url: URL) throws {
		guard let acl = acl_get_fd_np(descriptor, ACL_TYPE_EXTENDED) else {
			let error = errno
			if error == ENOENT { return }
			throw POSIXError(.init(rawValue: error) ?? .EIO)
		}
		defer { _ = acl_free(UnsafeMutableRawPointer(acl)) }
		var entry: acl_entry_t?
		guard acl_get_entry(acl, 0, &entry) == -1, errno == ENOENT else {
			throw InstallerFileSystemError.unsafeDirectory(url)
		}
	}

	private static func pathComponents(_ path: String) throws -> [String] {
		let components = path.split(separator: "/", omittingEmptySubsequences: false)
		guard !path.hasPrefix("/"),
			!components.isEmpty,
			components.allSatisfy({ component in
				!component.isEmpty
					&& component != "."
					&& component != ".."
					&& !component.contains("\\")
					&& !component.contains(where: { $0.isNewline || $0.asciiValue == 0 })
			})
		else { throw InstallerFileSystemError.invalidPath(path) }
		return components.map(String.init)
	}
}

/// An open directory reached relative to the pinned install root or private staging directory.
final class InstallerDirectoryHandle: @unchecked Sendable {
	let descriptor: Int32
	let url: URL

	init(descriptor: Int32, url: URL) {
		self.descriptor = descriptor
		self.url = url
	}

	deinit {
		_ = close(descriptor)
	}

	func file(named name: String) -> InstallerFilePath {
		InstallerFilePath(directory: self, name: name, url: url.appending(path: name))
	}

	func openDirectory(
		named name: String,
		create: Bool = false,
		mode: mode_t = 0o755
	) throws -> InstallerDirectoryHandle {
		try Self.validateLeaf(name)
		let childURL = url.appending(path: name, directoryHint: .isDirectory)
		var child = openat(
			descriptor,
			name,
			O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
		)
		if child < 0, errno == ENOENT, create {
			if mkdirat(descriptor, name, mode) != 0, errno != EEXIST {
				throw POSIXError(.init(rawValue: errno) ?? .EIO)
			}
			child = openat(
				descriptor,
				name,
				O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
			)
		}
		guard child >= 0 else {
			let openError = errno
			if openError == ELOOP || Self.isSymbolicLink(named: name, in: descriptor) {
				throw InstallerFileSystemError.symbolicLink(childURL)
			}
			throw POSIXError(.init(rawValue: openError) ?? .EIO)
		}
		var status = stat()
		let statusResult = fstat(child, &status)
		guard statusResult == 0, status.st_mode & S_IFMT == S_IFDIR else {
			let error = statusResult == 0 ? ENOTDIR : errno
			_ = close(child)
			throw POSIXError(.init(rawValue: error) ?? .ENOTDIR)
		}
		return InstallerDirectoryHandle(descriptor: child, url: childURL)
	}

	/// Other-UID isolation of staged names depends on the volume enforcing ownership and mode bits.
	/// Descriptor hashing and atomic rename still apply elsewhere, but cannot block hostile
	/// source-name replacement on ownership-ignored volumes.
	func stagingDirectory(named name: String) throws -> InstallerDirectoryHandle {
		let directory = try openDirectory(named: name, create: true, mode: 0o700)
		var status = stat()
		guard fstat(directory.descriptor, &status) == 0,
			status.st_mode & S_IFMT == S_IFDIR,
			status.st_uid == geteuid()
		else { throw InstallerFileSystemError.unsafeDirectory(directory.url) }
		guard fchmod(directory.descriptor, 0o700) == 0 else {
			throw POSIXError(.init(rawValue: errno) ?? .EIO)
		}
		try InstallerInstallDirectory.removeExtendedACL(
			from: directory.descriptor,
			at: directory.url
		)
		guard fstat(directory.descriptor, &status) == 0,
			status.st_uid == geteuid(),
			status.st_mode & 0o777 == 0o700
		else { throw InstallerFileSystemError.unsafeDirectory(directory.url) }
		try InstallerInstallDirectory.requireNoExtendedACL(
			on: directory.descriptor,
			at: directory.url
		)
		return directory
	}

	func statFile(named name: String) throws -> stat? {
		try Self.validateLeaf(name)
		var status = stat()
		guard fstatat(descriptor, name, &status, AT_SYMLINK_NOFOLLOW) == 0 else {
			if errno == ENOENT { return nil }
			throw POSIXError(.init(rawValue: errno) ?? .EIO)
		}
		if status.st_mode & S_IFMT == S_IFLNK {
			throw InstallerFileSystemError.symbolicLink(url.appending(path: name))
		}
		return status
	}

	func renameFile(named name: String, to directory: InstallerDirectoryHandle, as newName: String)
		throws
	{
		try Self.validateLeaf(name)
		try Self.validateLeaf(newName)
		guard renameat(descriptor, name, directory.descriptor, newName) == 0 else {
			throw POSIXError(.init(rawValue: errno) ?? .EIO)
		}
	}

	func unlinkFile(named name: String) throws {
		try Self.validateLeaf(name)
		guard unlinkat(descriptor, name, 0) == 0 else {
			if errno == ENOENT { return }
			throw POSIXError(.init(rawValue: errno) ?? .EIO)
		}
	}

	static func validateLeaf(_ name: String) throws {
		guard !name.isEmpty, name != ".", name != "..", !name.contains("/"),
			!name.contains("\\"),
			!name.contains(where: { $0.isNewline || $0.asciiValue == 0 })
		else { throw InstallerFileSystemError.invalidPath(name) }
	}

	private static func isSymbolicLink(named name: String, in directory: Int32) -> Bool {
		var status = stat()
		return fstatat(directory, name, &status, AT_SYMLINK_NOFOLLOW) == 0
			&& status.st_mode & S_IFMT == S_IFLNK
	}
}

/// A file name paired with its already-open parent directory, so later operations do not
/// resolve mutable parent path components again.
struct InstallerFilePath: @unchecked Sendable {
	let directory: InstallerDirectoryHandle
	let name: String
	let url: URL

	func sibling(named name: String) -> InstallerFilePath {
		directory.file(named: name)
	}

	func open(flags: Int32, mode: mode_t = 0) throws -> Int32 {
		try InstallerDirectoryHandle.validateLeaf(name)
		let descriptor = openat(directory.descriptor, name, flags | O_NONBLOCK, mode)
		guard descriptor >= 0 else {
			if errno == ELOOP { throw InstallerFileSystemError.symbolicLink(url) }
			throw POSIXError(.init(rawValue: errno) ?? .EIO)
		}
		return descriptor
	}

	func stat() throws -> stat? {
		try directory.statFile(named: name)
	}

	func rename(to destination: InstallerFilePath) throws {
		try directory.renameFile(named: name, to: destination.directory, as: destination.name)
	}

	func renameExclusively(to destination: InstallerFilePath) throws {
		try InstallerDirectoryHandle.validateLeaf(name)
		try InstallerDirectoryHandle.validateLeaf(destination.name)
		guard
			renameatx_np(
				directory.descriptor,
				name,
				destination.directory.descriptor,
				destination.name,
				UInt32(RENAME_EXCL)
			) == 0
		else { throw POSIXError(.init(rawValue: errno) ?? .EIO) }
	}

	func unlink() throws {
		try directory.unlinkFile(named: name)
	}
}
