// SPDX-License-Identifier: MPL-2.0

import Darwin
import Foundation

package enum JSONFileStoreError: Error, Sendable {
	case tooLarge(maximumBytes: Int)
}

/// Reads and writes one JSON document format with a hard size limit.
///
/// Output is `JSONEncoder` with sorted keys (and optional pretty printing), followed by one
/// newline. Reads go through `BoundedFileReader`, so the limit applies to both directions.
package struct JSONFileStore: Sendable {
	package let maximumBytes: Int
	private let prettyPrinted: Bool
	private let iso8601Dates: Bool

	package init(maximumBytes: Int, prettyPrinted: Bool = true, iso8601Dates: Bool = false) {
		self.maximumBytes = maximumBytes
		self.prettyPrinted = prettyPrinted
		self.iso8601Dates = iso8601Dates
	}

	/// Returns the bytes `write` stores, or throws `tooLarge`.
	package func encode<Value: Encodable>(_ value: Value) throws -> Data {
		let encoder = JSONEncoder()
		encoder.outputFormatting = prettyPrinted ? [.prettyPrinted, .sortedKeys] : [.sortedKeys]
		if iso8601Dates { encoder.dateEncodingStrategy = .iso8601 }
		var data = try encoder.encode(value)
		data.append(0x0A)
		guard data.count <= maximumBytes else {
			throw JSONFileStoreError.tooLarge(maximumBytes: maximumBytes)
		}
		return data
	}

	package func decode<Value: Decodable>(_ type: Value.Type, from data: Data) throws -> Value {
		let decoder = JSONDecoder()
		if iso8601Dates { decoder.dateDecodingStrategy = .iso8601 }
		return try decoder.decode(type, from: data)
	}

	/// Returns nil when the file does not exist. Decoding failures throw `DecodingError`;
	/// an oversized file throws `BoundedFileReadError.tooLarge`.
	package func read<Value: Decodable>(_ type: Value.Type, at url: URL) throws -> Value? {
		let data: Data
		do {
			data = try BoundedFileReader.readRegularFile(at: url, maximumBytes: maximumBytes)
		} catch let error as POSIXError where error.code == .ENOENT {
			return nil
		}
		return try decode(type, from: data)
	}

	/// Reads through a descriptor the caller opened without following symbolic links.
	package func read<Value: Decodable>(
		_ type: Value.Type,
		fileDescriptor: Int32,
		at url: URL
	) throws -> Value {
		let data = try BoundedFileReader.readRegularFile(
			fileDescriptor: fileDescriptor,
			at: url,
			maximumBytes: maximumBytes
		)
		return try decode(type, from: data)
	}

	/// Replaces the file atomically. Content may be lost on power failure before the system
	/// flushes it; use `writeDurably` when the file is authoritative state.
	package func write<Value: Encodable>(
		_ value: Value,
		to url: URL,
		createParentDirectory: Bool = false
	) throws {
		let data = try encode(value)
		if createParentDirectory {
			try FileManager.default.createDirectory(
				at: url.deletingLastPathComponent(),
				withIntermediateDirectories: true
			)
		}
		try data.write(to: url, options: .atomic)
	}

	/// Writes `temporary` exclusively, flushes it, renames it over `destination`, and flushes
	/// the parent directory, so a crash leaves either the old or the new complete file.
	package func writeDurably<Value: Encodable>(
		_ value: Value,
		to destination: InstallerFile,
		temporary: InstallerFile
	) throws {
		let data = try encode(value)
		let descriptor = try temporary.open(
			flags: O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW,
			mode: S_IRUSR | S_IWUSR
		)
		var temporaryExists = true
		defer {
			_ = close(descriptor)
			if temporaryExists {
				do {
					try temporary.unlink()
				} catch {
					// A failed cleanup cannot make an incomplete file authoritative.
				}
			}
		}
		try Self.write(data, to: descriptor)
		guard fsync(descriptor) == 0 else {
			throw POSIXError(.init(rawValue: errno) ?? .EIO)
		}
		try temporary.rename(to: destination)
		temporaryExists = false
		try destination.synchronizeParent()
	}

	private static func write(_ data: Data, to descriptor: Int32) throws {
		try data.withUnsafeBytes { buffer in
			guard let baseAddress = buffer.baseAddress else { return }
			var offset = 0
			while offset < buffer.count {
				let count = Darwin.write(
					descriptor,
					baseAddress.advanced(by: offset),
					buffer.count - offset
				)
				if count < 0 {
					if errno == EINTR { continue }
					throw POSIXError(.init(rawValue: errno) ?? .EIO)
				}
				guard count > 0 else { throw POSIXError(.EIO) }
				offset += count
			}
		}
	}
}
