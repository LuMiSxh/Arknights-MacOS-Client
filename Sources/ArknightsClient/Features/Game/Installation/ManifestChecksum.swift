// SPDX-License-Identifier: MPL-2.0

import CryptoKit
import Darwin
import Foundation

enum ManifestChecksum {
	/// Hashes `url` with the algorithm implied by `expected`, honoring task cancellation between
	/// buffers and reporting each buffer's size through `onRead`.
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

	/// Hashes an already-open inode without resolving its pathname again.
	static func checksum(
		ofFileDescriptor descriptor: Int32,
		expected: String,
		onRead: ((Int) -> Void)? = nil
	) throws -> String {
		var before = stat()
		guard fstat(descriptor, &before) == 0 else {
			throw POSIXError(.init(rawValue: errno) ?? .EIO)
		}
		guard before.st_mode & S_IFMT == S_IFREG, before.st_nlink == 1 else {
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
			let data = Data(buffer.prefix(count))
			if isMD5(expected) {
				md5.update(data: data)
			} else {
				crc64.update(data)
			}
			offset += off_t(count)
			onRead?(count)
		}
		var after = stat()
		guard fstat(descriptor, &after) == 0 else {
			throw POSIXError(.init(rawValue: errno) ?? .EIO)
		}
		guard InstallerFileIdentity(after) == InstallerFileIdentity(before),
			after.st_size == before.st_size,
			after.st_mtimespec.tv_sec == before.st_mtimespec.tv_sec,
			after.st_mtimespec.tv_nsec == before.st_mtimespec.tv_nsec,
			after.st_ctimespec.tv_sec == before.st_ctimespec.tv_sec,
			after.st_ctimespec.tv_nsec == before.st_ctimespec.tv_nsec
		else { throw POSIXError(.EBUSY) }
		return isMD5(expected)
			? md5.finalize().map { String(format: "%02x", $0) }.joined()
			: crc64.decimalString
	}

	private static func isMD5(_ value: String) -> Bool {
		value.count == 32 && value.allSatisfy(\.isHexDigit)
	}

}
