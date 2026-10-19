// SPDX-License-Identifier: MPL-2.0

import Darwin
import Foundation

package enum BoundedFileReadError: Error, Sendable {
	case invalidMaximum(Int)
	case notRegularFile(URL)
	case tooLarge(URL, maximumBytes: Int)
}

package enum BoundedFileReader {
	package static func readRegularFile(at url: URL, maximumBytes: Int) throws -> Data {
		guard maximumBytes >= 0, maximumBytes < Int.max else {
			throw BoundedFileReadError.invalidMaximum(maximumBytes)
		}
		let descriptor = open(url.path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK)
		guard descriptor >= 0 else {
			throw POSIXError(.init(rawValue: errno) ?? .EIO)
		}
		defer { _ = close(descriptor) }
		return try readRegularFile(
			fileDescriptor: descriptor,
			at: url,
			maximumBytes: maximumBytes
		)
	}

	package static func readRegularFile(
		fileDescriptor descriptor: Int32,
		at url: URL,
		maximumBytes: Int
	) throws -> Data {
		guard maximumBytes >= 0, maximumBytes < Int.max else {
			throw BoundedFileReadError.invalidMaximum(maximumBytes)
		}

		var status = stat()
		guard fstat(descriptor, &status) == 0 else {
			throw POSIXError(.init(rawValue: errno) ?? .EIO)
		}
		guard status.st_mode & S_IFMT == S_IFREG, status.st_nlink == 1 else {
			throw BoundedFileReadError.notRegularFile(url)
		}
		guard status.st_size >= 0, status.st_size <= Int64(maximumBytes) else {
			throw BoundedFileReadError.tooLarge(url, maximumBytes: maximumBytes)
		}

		// One byte beyond the stated size detects a file that grew after `fstat`.
		var data = Data(count: Int(status.st_size) + 1)
		var offset = 0
		while true {
			if offset == data.count {
				guard data.count <= maximumBytes else {
					throw BoundedFileReadError.tooLarge(url, maximumBytes: maximumBytes)
				}
				data.count = min(data.count * 2, maximumBytes + 1)
			}
			let (count, failure) = data.withUnsafeMutableBytes { buffer in
				let count = pread(
					descriptor,
					buffer.baseAddress?.advanced(by: offset),
					buffer.count - offset,
					off_t(offset)
				)
				return (count, errno)
			}
			if count < 0 {
				if failure == EINTR { continue }
				throw POSIXError(.init(rawValue: failure) ?? .EIO)
			}
			if count == 0 { break }
			offset += count
		}
		data.count = offset
		return data
	}
}
