// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsInfrastructure
import CryptoKit
import Darwin
import Foundation

enum ManifestChecksum {
	// Honors task cancellation between buffers and reports each buffer's size through `onRead`.
	static func checksum(
		of url: URL,
		expected: String,
		onRead: ((Int) -> Void)? = nil
	) throws -> String {
		let descriptor = open(
			url.path,
			O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK
		)
		guard descriptor >= 0 else { throw POSIXError(.init(rawValue: errno) ?? .EIO) }
		defer { _ = close(descriptor) }
		return try checksum(
			ofFileDescriptor: descriptor,
			expected: expected,
			onRead: onRead
		)
	}

	static func matches(_ actual: String, expected: String) -> Bool {
		isMD5(expected)
			? actual.caseInsensitiveCompare(expected) == .orderedSame
			: actual == expected
	}

	// Hashes an already-open regular file with one hard link.
	static func checksum(
		ofFileDescriptor descriptor: Int32,
		expected: String,
		bufferSize: Int = AppConstants.IO.checksumBufferSize,
		onRead: ((Int) -> Void)? = nil
	) throws -> String {
		var status = stat()
		guard fstat(descriptor, &status) == 0 else {
			throw POSIXError(.init(rawValue: errno) ?? .EIO)
		}
		guard status.st_mode & S_IFMT == S_IFREG, status.st_nlink == 1 else {
			throw POSIXError(.EINVAL)
		}
		// A file smaller than one buffer reads in one pass; an empty file still gets one byte.
		let chunkSize = max(1, min(Int(clamping: status.st_size), bufferSize))
		let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: chunkSize, alignment: 1)
		defer { buffer.deallocate() }
		let usesMD5 = isMD5(expected)
		var md5 = Insecure.MD5()
		var crc64 = CRC64()
		var offset: off_t = 0
		while true {
			try Task.checkCancellation()
			let count = pread(descriptor, buffer.baseAddress, buffer.count, offset)
			if count < 0 {
				if errno == EINTR { continue }
				throw POSIXError(.init(rawValue: errno) ?? .EIO)
			}
			guard count > 0 else { break }
			let chunk = UnsafeRawBufferPointer(start: buffer.baseAddress, count: count)
			if usesMD5 {
				md5.update(bufferPointer: chunk)
			} else {
				crc64.update(chunk)
			}
			offset += off_t(count)
			onRead?(count)
		}
		return usesMD5
			? md5.finalize().hexString
			: crc64.decimalString
	}

	static func isMD5(_ value: String) -> Bool {
		value.count == 32 && value.allSatisfy(\.isHexDigit)
	}

}
