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
		onRead: ((Int) -> Void)? = nil
	) throws -> String {
		var status = stat()
		guard fstat(descriptor, &status) == 0 else {
			throw POSIXError(.init(rawValue: errno) ?? .EIO)
		}
		guard status.st_mode & S_IFMT == S_IFREG, status.st_nlink == 1 else {
			throw POSIXError(.EINVAL)
		}
		var md5 = Insecure.MD5()
		var crc64 = CRC64()
		var offset: off_t = 0
		var buffer = [UInt8](repeating: 0, count: AppConstants.IO.checksumBufferSize)
		while true {
			try Task.checkCancellation()
			let count = buffer.withUnsafeMutableBytes { bytes in
				pread(descriptor, bytes.baseAddress, bytes.count, offset)
			}
			if count < 0 {
				if errno == EINTR { continue }
				throw POSIXError(.init(rawValue: errno) ?? .EIO)
			}
			guard count > 0 else { break }
			buffer.withUnsafeBytes { bytes in
				let chunk = UnsafeRawBufferPointer(rebasing: bytes.prefix(count))
				if isMD5(expected) {
					md5.update(bufferPointer: chunk)
				} else {
					crc64.update(chunk)
				}
			}
			offset += off_t(count)
			onRead?(count)
		}
		return isMD5(expected)
			? md5.finalize().hexString
			: crc64.decimalString
	}

	static func isMD5(_ value: String) -> Bool {
		value.count == 32 && value.allSatisfy(\.isHexDigit)
	}

}
