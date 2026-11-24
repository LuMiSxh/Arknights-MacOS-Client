// SPDX-License-Identifier: MPL-2.0

import Darwin
import Foundation

/// Failures from reading and extracting a downloaded runtime archive.
enum RuntimeArchiveError: Error, Equatable, Sendable {
	case unsafePath(String)
	case escapingLink(String)
	case platformMetadata(String)
	case invalidHeader(String)
	case notSingleTopLevelDirectory
	case unsupportedEntry(String)
	case decompressionFailed(String)
}

/// Extracts a verified `.tar.xz` runtime archive or delta into a fresh staging directory and
/// returns the single top-level directory inside it. A runtime archive has one `Runtime/`
/// directory whose contents are the installed root; a delta has one `Delta/` directory.
///
/// Path safety mirrors `scripts/lib/extract_runtime.py`: absolute paths, `..`, Windows drive
/// prefixes, `__MACOSX`, `._*`, hard links, and symlinks that leave the root are rejected before
/// anything is written.
enum RuntimeArchive {
	static let runtimeRoot = "Runtime"
	static let deltaRoot = "Delta"

	static func extract(
		at archiveURL: URL,
		into destination: URL,
		expectedRoot: String = runtimeRoot,
		fileManager: FileManager = .default
	) throws -> URL {
		let temporary = destination.deletingLastPathComponent()
			.appending(path: "\(UUID().uuidString).tar")
		try fileManager.createDirectory(
			at: temporary.deletingLastPathComponent(), withIntermediateDirectories: true)
		defer {
			// best effort: a leftover decompressed tar is never authoritative.
			try? fileManager.removeItem(at: temporary)
		}
		try decompressXZ(at: archiveURL, to: temporary)

		try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
		return try extractTar(at: temporary, into: destination, expectedRoot: expectedRoot)
	}

	// MARK: - Tar

	private static func extractTar(
		at tarURL: URL, into destination: URL, expectedRoot: String
	) throws -> URL {
		let handle = try FileHandle(forReadingFrom: tarURL)

		var topLevels = Set<String>()
		var pendingLongName: String?
		var pendingLongLink: String?

		while true {
			let headerData = try readHeader(from: handle)
			guard !headerData.isEmpty else { break }
			guard headerData.count == 512 else {
				throw RuntimeArchiveError.invalidHeader("truncated tar header")
			}
			let header = [UInt8](headerData)
			if header.allSatisfy({ $0 == 0 }) { break }

			let typeFlag = header[156]
			let size = parseOctal(header, 124..<136)
			let name = parseString(header, 0..<100)
			let prefix = parseString(header, 345..<500)
			let linkName = parseString(header, 157..<257)

			switch typeFlag {
			case 0x4C:  // 'L' GNU long name
				pendingLongName = try readLongValue(from: handle, byteCount: size)
				continue
			case 0x4B:  // 'K' GNU long link
				pendingLongLink = try readLongValue(from: handle, byteCount: size)
				continue
			case 0x78:  // 'x' per-file PAX extended header
				// bsdtar writes a PAX header before every entry; keep the path fields.
				let records = try readPaxRecords(from: handle, byteCount: size)
				if let path = records["path"] { pendingLongName = path }
				if let linkpath = records["linkpath"] { pendingLongLink = linkpath }
				continue
			case 0x67:  // 'g' global PAX extended header
				_ = try readPaxRecords(from: handle, byteCount: size)
				continue
			default:
				break
			}

			let resolvedName = pendingLongName ?? combine(prefix: prefix, name: name)
			let resolvedLink = pendingLongLink ?? linkName
			pendingLongName = nil
			pendingLongLink = nil

			try validateName(resolvedName)
			let components = pathComponents(of: resolvedName)
			if let first = components.first {
				topLevels.insert(String(first))
			}

			switch typeFlag {
			case 0, 0x30, 0x37:  // regular file ('\0', '0', '7')
				try extractRegularFile(
					from: handle, name: resolvedName, components: components, size: size,
					mode: parseOctal(header, 100..<108), into: destination)
			case 0x35:  // '5' directory
				try createDirectory(components: components, under: destination)
			case 0x32:  // '2' symlink
				try validateLinkTarget(
					resolvedLink, sourceDirectory: components.dropFirst().dropLast())
				try createParents(components.dropLast(), under: destination)
				let target = destinationPath(for: components, under: destination)
				guard Darwin.symlink(resolvedLink, target) == 0 else {
					throw POSIXError(.init(rawValue: errno) ?? .EIO)
				}
			default:  // Hard links, devices, and FIFOs never appear in a runtime archive.
				throw RuntimeArchiveError.unsupportedEntry(resolvedName)
			}
		}

		guard topLevels == [expectedRoot] else {
			throw RuntimeArchiveError.notSingleTopLevelDirectory
		}
		let rootURL = destination.appending(path: expectedRoot, directoryHint: .isDirectory)
		var status = stat()
		guard lstat(rootURL.path, &status) == 0, status.st_mode & S_IFMT == S_IFDIR else {
			throw RuntimeArchiveError.notSingleTopLevelDirectory
		}
		return rootURL
	}

	// MARK: - Entry handling

	private static func extractRegularFile(
		from handle: FileHandle,
		name: String,
		components: [String],
		size: Int,
		mode: Int,
		into destination: URL
	) throws {
		try createParents(components.dropLast(), under: destination)
		let fileURL = destinationPath(for: components, under: destination)
		let descriptor = Darwin.open(
			fileURL, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC,
			S_IRUSR | S_IWUSR
		)
		guard descriptor >= 0 else {
			if errno == ELOOP { throw RuntimeArchiveError.unsafePath(name) }
			throw POSIXError(.init(rawValue: errno) ?? .EIO)
		}
		defer { _ = close(descriptor) }
		// Wine's binaries are executable, so preserve the archive's permission bits instead of
		// leaving every extracted file owner-readable only.
		let permissions = mode_t(mode & 0o777)
		guard fchmod(descriptor, permissions == 0 ? 0o644 : permissions) == 0 else {
			throw POSIXError(.init(rawValue: errno) ?? .EIO)
		}

		var remaining = size
		while remaining > 0 {
			let chunk = min(256 * 1_024, remaining)
			let data = try readBlock(from: handle, count: chunk)
			guard !data.isEmpty else {
				throw RuntimeArchiveError.invalidHeader("truncated tar entry")
			}
			try data.withUnsafeBytes { buffer in
				try writeAll(buffer, to: descriptor)
			}
			remaining -= data.count
		}
		let padding = (512 - (size % 512)) % 512
		if padding > 0 { _ = try readBlock(from: handle, count: padding) }
	}

	private static func createDirectory(components: [String], under destination: URL) throws {
		try createParents(components[...], under: destination)
	}

	private static func createParents(
		_ components: ArraySlice<String>, under destination: URL
	) throws {
		var current = destination.path
		for component in components {
			current = current + "/" + component
			var status = stat()
			if lstat(current, &status) == 0 {
				guard status.st_mode & S_IFMT == S_IFDIR else {
					throw RuntimeArchiveError.unsafePath(current)
				}
				continue
			}
			guard errno == ENOENT else {
				throw POSIXError(.init(rawValue: errno) ?? .EIO)
			}
			guard Darwin.mkdir(current, 0o755) == 0 else {
				throw POSIXError(.init(rawValue: errno) ?? .EIO)
			}
			guard lstat(current, &status) == 0, status.st_mode & S_IFMT == S_IFDIR else {
				throw RuntimeArchiveError.unsafePath(current)
			}
		}
	}

	private static func destinationPath(
		for components: [String], under destination: URL
	) -> String {
		destination.path + "/" + components.joined(separator: "/")
	}

	private static func readLongValue(from handle: FileHandle, byteCount: Int) throws -> String {
		let data = try readBlock(from: handle, count: byteCount)
		let padding = (512 - (byteCount % 512)) % 512
		if padding > 0 { _ = try readBlock(from: handle, count: padding) }
		guard
			let value = String(data: data, encoding: .utf8)?.trimmingCharacters(
				in: CharacterSet(charactersIn: "\0"))
		else {
			throw RuntimeArchiveError.invalidHeader("invalid long name")
		}
		return value
	}

	private static func readPaxRecords(
		from handle: FileHandle, byteCount: Int
	) throws -> [String: String] {
		let data = try readBlock(from: handle, count: byteCount)
		let padding = (512 - (byteCount % 512)) % 512
		if padding > 0 { _ = try readBlock(from: handle, count: padding) }
		return try parsePaxRecords([UInt8](data))
	}

	private static func parsePaxRecords(_ bytes: [UInt8]) throws -> [String: String] {
		var index = 0
		var records: [String: String] = [:]
		while index < bytes.count {
			guard bytes[index] != 0 else { break }
			var space = index
			while space < bytes.count, bytes[space] != 0x20 { space += 1 }
			guard space < bytes.count,
				let length = Int(String(decoding: bytes[index..<space], as: UTF8.self)),
				length > space - index + 1,
				index + length <= bytes.count
			else {
				throw RuntimeArchiveError.invalidHeader("malformed PAX header")
			}
			let record = bytes[(space + 1)..<(index + length)]
			guard record.last == 0x0A,
				let equals = record.firstIndex(of: 0x3D),
				equals < record.endIndex - 1
			else {
				throw RuntimeArchiveError.invalidHeader("malformed PAX record")
			}
			let key = String(decoding: record[..<equals], as: UTF8.self)
			let value = String(
				decoding: record[(equals + 1)..<(record.endIndex - 1)], as: UTF8.self)
			records[key] = value
			index += length
		}
		return records
	}

	private static func readHeader(from handle: FileHandle) throws -> Data {
		if let data = try handle.read(upToCount: 512), !data.isEmpty { return data }
		return Data()
	}

	// Writes the whole buffer, retrying short writes and EINTR.
	static func writeAll(_ bytes: UnsafeRawBufferPointer, to descriptor: Int32) throws {
		guard let baseAddress = bytes.baseAddress else { return }
		var written = 0
		while written < bytes.count {
			let count = Darwin.write(
				descriptor, baseAddress.advanced(by: written), bytes.count - written)
			if count < 0 {
				if errno == EINTR { continue }
				throw POSIXError(.init(rawValue: errno) ?? .EIO)
			}
			guard count > 0 else { throw POSIXError(.EIO) }
			written += count
		}
	}

	private static func readBlock(from handle: FileHandle, count: Int) throws -> Data {
		var remaining = count
		var result = Data()
		while remaining > 0 {
			guard let data = try handle.read(upToCount: remaining), !data.isEmpty else {
				throw RuntimeArchiveError.invalidHeader("truncated tar entry")
			}
			result.append(data)
			remaining -= data.count
		}
		return result
	}

	// MARK: - Path validation

	private static func combine(prefix: String, name: String) -> String {
		prefix.isEmpty ? name : "\(prefix)/\(name)"
	}

	private static func pathComponents(of value: String) -> [String] {
		let trimmed = value.hasSuffix("/") ? String(value.dropLast()) : value
		return trimmed.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
	}

	private static func validateName(_ name: String) throws {
		guard !name.isEmpty else { throw RuntimeArchiveError.invalidHeader("empty entry name") }
		let trimmed = name.hasSuffix("/") ? String(name.dropLast()) : name
		guard !trimmed.hasPrefix("/") else { throw RuntimeArchiveError.unsafePath(name) }
		guard !trimmed.contains("\\") else { throw RuntimeArchiveError.unsafePath(name) }
		if trimmed.count >= 2, let first = trimmed.first, first.isLetter,
			trimmed[trimmed.index(after: trimmed.startIndex)] == ":"
		{
			throw RuntimeArchiveError.unsafePath(name)
		}
		let components = trimmed.split(separator: "/", omittingEmptySubsequences: false)
		for component in components where component == ".." || component.isEmpty || component == "."
		{
			throw RuntimeArchiveError.unsafePath(name)
		}
		if components.first == "__MACOSX" || components.contains(where: { $0.hasPrefix("._") }) {
			throw RuntimeArchiveError.platformMetadata(name)
		}
	}

	/// Rejects a symlink target that is absolute, Windows-style, or resolves above the root.
	/// `sourceDirectory` is the link's parent directory relative to that root.
	static func validateLinkTarget(
		_ target: String,
		sourceDirectory: ArraySlice<String>
	) throws {
		guard !target.hasPrefix("/") else { throw RuntimeArchiveError.escapingLink(target) }
		guard !target.contains("\\") else { throw RuntimeArchiveError.escapingLink(target) }
		if target.count >= 2, let first = target.first, first.isLetter,
			target[target.index(after: target.startIndex)] == ":"
		{
			throw RuntimeArchiveError.escapingLink(target)
		}
		var stack = Array(sourceDirectory)
		for component in target.split(separator: "/", omittingEmptySubsequences: false) {
			if component.isEmpty || component == "." { continue }
			if component == ".." {
				guard !stack.isEmpty else { throw RuntimeArchiveError.escapingLink(target) }
				stack.removeLast()
			} else {
				stack.append(String(component))
			}
		}
	}

	// MARK: - Header parsing

	private static func parseOctal(_ bytes: [UInt8], _ range: Range<Int>) -> Int {
		var value = 0
		for byte in bytes[range] {
			if byte == 0 || byte == 0x20 { continue }
			value = value * 8 + Int(byte - 0x30)
		}
		return value
	}

	private static func parseString(_ bytes: [UInt8], _ range: Range<Int>) -> String {
		var result: [UInt8] = []
		for byte in bytes[range] {
			if byte == 0 { break }
			result.append(byte)
		}
		return String(decoding: result, as: UTF8.self)
	}
}
