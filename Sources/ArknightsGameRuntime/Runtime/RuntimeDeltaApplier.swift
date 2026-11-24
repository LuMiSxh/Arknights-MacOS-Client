// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameInstallation
import CryptoKit
import Darwin
import Foundation

/// Builds the target runtime tree of a delta in a private staging directory.
///
/// The installed runtime is cloned (APFS `clonefile`, never following symlinks), so unchanged
/// files cost no disk space. Every path the plan touches is checked per component with `lstat`,
/// every source file is hashed before it is reused or patched, and every result is hashed before
/// it is written. Any mismatch throws and the caller discards the staging tree.
enum RuntimeDeltaApplier {
	/// Clones `source` to `target` (which must not exist) and turns the clone into the plan's tree.
	@concurrent
	static func apply(
		plan: RuntimeDeltaPlan, deltaRoot: URL, source: URL, target: URL
	) async throws {
		try clone(source.path, to: target.path)
		let root = target.path
		try removeIfPresent(root + "/RUNTIME.json")

		var expected: [String: RuntimeDeltaPlan.Node] = [:]
		for item in plan.items { expected[item.path] = item.node }
		try prune(directory: root, relative: "", expected: expected)

		let ordered = plan.items.sorted {
			($0.components.count, $0.path) < ($1.components.count, $1.path)
		}
		for item in ordered {
			try Task.checkCancellation()
			try requireRealDirectories(root, item.components.dropLast())
			let path = root + "/" + item.path
			switch item.node {
			case .directory:
				if try fileType(atPath: path) == nil {
					guard mkdir(path, 0o755) == 0 else { throw posixError() }
				}
			case .symlink(let target):
				if try fileType(atPath: path) == S_IFLNK,
					try FileManager.default.destinationOfSymbolicLink(atPath: path) == target
				{
					continue
				}
				try removeIfPresent(path)
				guard Darwin.symlink(target, path) == 0 else { throw posixError() }
			case .file(let executable, let size, let sha256, let action):
				try materialize(
					path: path, name: item.path, executable: executable, size: size,
					sha256: sha256, action: action, deltaRoot: deltaRoot)
			}
		}
		try verifyShape(root: root, expected: expected)
	}

	// MARK: - Tree

	private static func clone(_ source: String, to target: String) throws {
		guard try fileType(atPath: source) == S_IFDIR else {
			throw RuntimeDeltaError.sourceMismatch("the installed runtime is not a directory")
		}
		guard clonefile(source, target, UInt32(CLONE_NOFOLLOW)) == 0 else {
			throw RuntimeDeltaError.cloneFailed(errno)
		}
	}

	/// Removes every path the plan does not list, or lists with another type.
	private static func prune(
		directory: String, relative: String, expected: [String: RuntimeDeltaPlan.Node]
	) throws {
		for name in try FileManager.default.contentsOfDirectory(atPath: directory) {
			try Task.checkCancellation()
			let path = directory + "/" + name
			let key = relative.isEmpty ? name : relative + "/" + name
			let type = try fileType(atPath: path)
			if let node = expected[key], type == expectedType(node) {
				if type == S_IFDIR { try prune(directory: path, relative: key, expected: expected) }
			} else {
				try removeIfPresent(path)
			}
		}
	}

	private static func materialize(
		path: String, name: String, executable: Bool, size: Int, sha256: String,
		action: RuntimeDeltaPlan.FileAction, deltaRoot: URL
	) throws {
		switch action {
		case .keep(let sourceSHA256):
			let descriptor = try openRegularFile(path)
			defer { _ = close(descriptor) }
			var status = stat()
			guard fstat(descriptor, &status) == 0, Int(status.st_size) == size,
				try hash(descriptor: descriptor) == sourceSHA256
			else {
				throw RuntimeDeltaError.sourceMismatch(name)
			}
			guard fchmod(descriptor, executable ? 0o755 : 0o644) == 0 else { throw posixError() }
		case .patch(let sourceSHA256, let data):
			let old = try MappedFile(
				path: path, maximumBytes: AppConstants.Runtime.deltaFileMaximumBytes)
			guard sha256Hex(old.bytes) == sourceSHA256 else {
				throw RuntimeDeltaError.sourceMismatch(name)
			}
			let patch = try mapDeltaFile(data, in: deltaRoot)
			let result = try RuntimeBinaryPatch.apply(
				patch: patch.bytes, to: old.bytes, maximumNewSize: size)
			try write(
				result, to: path, name: name, size: size, sha256: sha256, executable: executable)
		case .add(let data):
			let content = try mapDeltaFile(data, in: deltaRoot)
			try write(
				content.bytes, to: path, name: name, size: size, sha256: sha256,
				executable: executable)
		}
	}

	private static func write(
		_ bytes: [UInt8], to path: String, name: String, size: Int, sha256: String,
		executable: Bool
	) throws {
		try bytes.withUnsafeBytes {
			try write($0, to: path, name: name, size: size, sha256: sha256, executable: executable)
		}
	}

	/// Checks size and hash, then replaces `path` through a `.part` file and an atomic rename.
	private static func write(
		_ bytes: UnsafeRawBufferPointer, to path: String, name: String, size: Int,
		sha256: String, executable: Bool
	) throws {
		guard bytes.count == size, sha256Hex(bytes) == sha256 else {
			throw RuntimeDeltaError.resultMismatch(name)
		}
		let temporary = path + ".\(UUID().uuidString).part"
		let descriptor = Darwin.open(
			temporary, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, S_IRUSR | S_IWUSR)
		guard descriptor >= 0 else { throw posixError() }
		do {
			try RuntimeArchive.writeAll(bytes, to: descriptor)
			guard fchmod(descriptor, executable ? 0o755 : 0o644) == 0 else { throw posixError() }
		} catch {
			_ = close(descriptor)
			_ = unlink(temporary)
			throw error
		}
		_ = close(descriptor)
		guard rename(temporary, path) == 0 else {
			let failure = posixError()
			_ = unlink(temporary)
			throw failure
		}
	}

	private static func mapDeltaFile(_ components: [String], in deltaRoot: URL) throws -> MappedFile
	{
		try requireRealDirectories(deltaRoot.path, components.dropLast())
		return try MappedFile(
			path: deltaRoot.path + "/" + components.joined(separator: "/"),
			maximumBytes: AppConstants.Runtime.deltaFileMaximumBytes)
	}

	/// The result must match the plan exactly: same paths, types, link targets, sizes, and modes.
	private static func verifyShape(
		root: String, expected: [String: RuntimeDeltaPlan.Node]
	) throws {
		var remaining = expected
		func visit(directory: String, relative: String) throws {
			for name in try FileManager.default.contentsOfDirectory(atPath: directory) {
				let path = directory + "/" + name
				let key = relative.isEmpty ? name : relative + "/" + name
				guard let node = remaining.removeValue(forKey: key),
					try fileType(atPath: path) == expectedType(node)
				else {
					throw RuntimeDeltaError.resultMismatch(key)
				}
				switch node {
				case .directory:
					try visit(directory: path, relative: key)
				case .symlink(let target):
					guard try FileManager.default.destinationOfSymbolicLink(atPath: path) == target
					else { throw RuntimeDeltaError.resultMismatch(key) }
				case .file(let executable, let size, _, _):
					var status = stat()
					guard lstat(path, &status) == 0, Int(status.st_size) == size,
						(status.st_mode & 0o111 != 0) == executable
					else { throw RuntimeDeltaError.resultMismatch(key) }
				}
			}
		}
		try visit(directory: root, relative: "")
		if let missing = remaining.keys.min() { throw RuntimeDeltaError.resultMismatch(missing) }
	}

	// MARK: - Primitives

	private static func expectedType(_ node: RuntimeDeltaPlan.Node) -> mode_t {
		switch node {
		case .directory: S_IFDIR
		case .symlink: S_IFLNK
		case .file: S_IFREG
		}
	}

	private static func posixError() -> POSIXError {
		POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
	}

	/// The `lstat` file type of `path`, or nil when nothing exists there.
	private static func fileType(atPath path: String) throws -> mode_t? {
		var status = stat()
		if lstat(path, &status) == 0 { return status.st_mode & S_IFMT }
		guard errno == ENOENT else { throw posixError() }
		return nil
	}

	private static func removeIfPresent(_ path: String) throws {
		guard try fileType(atPath: path) != nil else { return }
		try FileManager.default.removeItem(atPath: path)
	}

	/// Requires each directory on the way to be a real directory, never a symlink.
	private static func requireRealDirectories(
		_ root: String, _ components: ArraySlice<String>
	) throws {
		var current = root
		for component in components {
			current += "/" + component
			guard try fileType(atPath: current) == S_IFDIR else {
				throw RuntimeDeltaError.unsafePath(current)
			}
		}
	}

	private static func openRegularFile(_ path: String) throws -> Int32 {
		let descriptor = Darwin.open(path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
		guard descriptor >= 0 else {
			if errno == ELOOP { throw RuntimeDeltaError.unsafePath(path) }
			throw posixError()
		}
		var status = stat()
		guard fstat(descriptor, &status) == 0, status.st_mode & S_IFMT == S_IFREG else {
			_ = close(descriptor)
			throw RuntimeDeltaError.sourceMismatch(path)
		}
		return descriptor
	}

	private static func sha256Hex(_ bytes: UnsafeRawBufferPointer) -> String {
		var hasher = SHA256()
		hasher.update(bufferPointer: bytes)
		return hasher.finalize().hexString
	}

	private static func hash(descriptor: Int32) throws -> String {
		let size = AppConstants.IO.checksumBufferSize
		let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: size, alignment: 16)
		defer { buffer.deallocate() }
		var hasher = SHA256()
		while true {
			let count = Darwin.read(descriptor, buffer.baseAddress, size)
			if count < 0 {
				if errno == EINTR { continue }
				throw posixError()
			}
			if count == 0 { break }
			hasher.update(bufferPointer: UnsafeRawBufferPointer(rebasing: buffer[0..<count]))
		}
		return hasher.finalize().hexString
	}

	/// A read-only memory map of a regular file, which `O_NOFOLLOW` guarantees is not a symlink.
	private struct MappedFile: ~Copyable {
		private let base: UnsafeMutableRawPointer?
		private let count: Int

		var bytes: UnsafeRawBufferPointer { UnsafeRawBufferPointer(start: base, count: count) }

		init(path: String, maximumBytes: Int) throws {
			let descriptor = try RuntimeDeltaApplier.openRegularFile(path)
			defer { _ = close(descriptor) }
			var status = stat()
			guard fstat(descriptor, &status) == 0 else { throw RuntimeDeltaApplier.posixError() }
			let length = Int(status.st_size)
			guard length <= maximumBytes else {
				throw RuntimeDeltaError.invalidManifest("\(path) is too large")
			}
			var mapping: UnsafeMutableRawPointer?
			if length > 0 {
				guard let mapped = mmap(nil, length, PROT_READ, MAP_PRIVATE, descriptor, 0),
					mapped != MAP_FAILED
				else {
					throw RuntimeDeltaApplier.posixError()
				}
				mapping = mapped
			}
			base = mapping
			count = length
		}

		deinit {
			if let base { munmap(base, count) }
		}
	}
}
