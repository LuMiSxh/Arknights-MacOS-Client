// SPDX-License-Identifier: MPL-2.0

import Czlib
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

/// Extracts a verified runtime archive into a fresh staging directory and returns the single
/// runtime directory inside it. The archive may be a gzip-compressed or plain tar.
///
/// Path safety mirrors `scripts/lib/extract_runtime.py`: absolute paths, `..`, Windows drive
/// prefixes, `__MACOSX`, `._*`, and symlinks or hard links that leave the archive are rejected
/// before anything is written.
enum RuntimeArchive {
	private static let companions = Set(["Licenses", "NOTICE.md"])

	static func extract(
		at archiveURL: URL,
		into destination: URL,
		fileManager: FileManager = .default
	) throws -> URL {
		let tarURL: URL
		var temporaryTarURL: URL?
		if try isGzip(at: archiveURL) {
			let temporary = destination.deletingLastPathComponent()
				.appending(path: "\(UUID().uuidString).tar")
			try fileManager.createDirectory(
				at: temporary.deletingLastPathComponent(), withIntermediateDirectories: true)
			try decompressGzip(at: archiveURL, to: temporary)
			temporaryTarURL = temporary
			tarURL = temporary
		} else {
			tarURL = archiveURL
		}
		defer {
			if let temporaryTarURL {
				// best effort: a leftover decompressed tar is never authoritative.
				try? fileManager.removeItem(at: temporaryTarURL)
			}
		}

		try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
		return try extractTar(at: tarURL, into: destination)
	}

	// MARK: - Gzip

	private static func isGzip(at url: URL) throws -> Bool {
		let handle = try FileHandle(forReadingFrom: url)
		return try handle.read(upToCount: 2) == Data([0x1F, 0x8B])
	}

	private static func decompressGzip(at source: URL, to destination: URL) throws {
		let input = try FileHandle(forReadingFrom: source)
		guard FileManager.default.createFile(atPath: destination.path, contents: nil) else {
			throw RuntimeArchiveError.decompressionFailed(
				"could not create \(destination.path)")
		}
		let output = try FileHandle(forWritingTo: destination)

		var stream = z_stream()
		// 15 + 32 accepts both gzip and zlib wrappers.
		guard
			inflateInit2_(&stream, 15 + 32, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
				== Z_OK
		else {
			throw RuntimeArchiveError.decompressionFailed("could not initialize decompression")
		}
		defer { inflateEnd(&stream) }

		var inputBuffer = [UInt8](repeating: 0, count: 256 * 1_024)
		var outputBuffer = [UInt8](repeating: 0, count: 256 * 1_024)
		var inputRemaining = 0
		var inputOffset = 0
		var reachedEnd = false

		while true {
			if inputOffset >= inputRemaining, !reachedEnd {
				if let data = try input.read(upToCount: inputBuffer.count), !data.isEmpty {
					inputRemaining = data.count
					inputOffset = 0
					data.copyBytes(to: &inputBuffer, count: data.count)
				} else {
					reachedEnd = true
				}
			}

			let flush: Int32 = reachedEnd ? Z_FINISH : Z_NO_FLUSH
			let status: Int32 = inputBuffer.withUnsafeMutableBytes { inputBytes in
				outputBuffer.withUnsafeMutableBytes { outputBytes in
					stream.next_in = inputBytes.baseAddress?.assumingMemoryBound(to: UInt8.self)
						.advanced(by: inputOffset)
					stream.avail_in = uInt(inputRemaining - inputOffset)
					stream.next_out = outputBytes.baseAddress?.assumingMemoryBound(to: UInt8.self)
					stream.avail_out = uInt(outputBytes.count)
					return inflate(&stream, flush)
				}
			}
			let produced = outputBuffer.count - Int(stream.avail_out)
			inputOffset = inputRemaining - Int(stream.avail_in)

			if produced > 0 {
				try output.write(contentsOf: Data(outputBuffer[0..<produced]))
			}
			if status == Z_STREAM_END { break }
			if status == Z_OK || status == Z_BUF_ERROR {
				if produced == 0, reachedEnd, stream.avail_in == 0 {
					throw RuntimeArchiveError.decompressionFailed("truncated gzip stream")
				}
				continue
			}
			throw RuntimeArchiveError.decompressionFailed(
				"decompression failed with status \(status)")
		}
	}

	// MARK: - Tar

	private static func extractTar(at tarURL: URL, into destination: URL) throws -> URL {
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
					resolvedLink, sourceDirectory: components.dropLast(), isSymlink: true)
				try createParents(components.dropLast(), under: destination)
				let target = try destinationPath(for: components, under: destination)
				guard Darwin.symlink(resolvedLink, target) == 0 else {
					throw POSIXError(.init(rawValue: errno) ?? .EIO)
				}
			case 0x31:  // '1' hard link
				try validateLinkTarget(resolvedLink, sourceDirectory: [], isSymlink: false)
				try createParents(components.dropLast(), under: destination)
				let target = try destinationPath(for: components, under: destination)
				let linkTarget = try destinationPath(
					for: pathComponents(of: resolvedLink), under: destination)
				guard Darwin.link(linkTarget, target) == 0 else {
					throw POSIXError(.init(rawValue: errno) ?? .EIO)
				}
			default:
				throw RuntimeArchiveError.unsupportedEntry(resolvedName)
			}
		}

		let roots = topLevels.subtracting(companions)
		guard roots.count == 1, let root = roots.first else {
			throw RuntimeArchiveError.notSingleTopLevelDirectory
		}
		let rootURL = destination.appending(path: root, directoryHint: .isDirectory)
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
		let fileURL = try destinationPath(for: components, under: destination)
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
			try data.withUnsafeBytes { buffer in
				guard let baseAddress = buffer.baseAddress else { return }
				var written = 0
				while written < buffer.count {
					let count = Darwin.write(
						descriptor, baseAddress.advanced(by: written), buffer.count - written)
					if count < 0 {
						if errno == EINTR { continue }
						throw POSIXError(.init(rawValue: errno) ?? .EIO)
					}
					written += count
				}
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
	) throws
		-> String
	{
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

	private static func validateLinkTarget(
		_ target: String,
		sourceDirectory: ArraySlice<String>,
		isSymlink: Bool
	) throws {
		guard !target.hasPrefix("/") else { throw RuntimeArchiveError.escapingLink(target) }
		guard !target.contains("\\") else { throw RuntimeArchiveError.escapingLink(target) }
		if target.count >= 2, let first = target.first, first.isLetter,
			target[target.index(after: target.startIndex)] == ":"
		{
			throw RuntimeArchiveError.escapingLink(target)
		}
		let base = isSymlink ? sourceDirectory.joined(separator: "/") : ""
		let joined = base.isEmpty ? target : "\(base)/\(target)"
		var stack: [String] = []
		for component in joined.split(separator: "/", omittingEmptySubsequences: false) {
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
