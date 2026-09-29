// SPDX-License-Identifier: MPL-2.0

import Darwin
import Foundation

enum BoundedFileReadError: Error, Sendable {
	case invalidMaximum(Int)
	case notRegularFile(URL)
	case tooLarge(URL, maximumBytes: Int)
}

enum BoundedFileReader {
	static func readRegularFile(at url: URL, maximumBytes: Int) throws -> Data {
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

	static func readRegularFile(
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

		var data = Data(count: maximumBytes + 1)
		let count = data.withUnsafeMutableBytes {
			pread(descriptor, $0.baseAddress, $0.count, 0)
		}
		guard count >= 0 else { throw POSIXError(.init(rawValue: errno) ?? .EIO) }
		data.count = count
		guard data.count <= maximumBytes else {
			throw BoundedFileReadError.tooLarge(url, maximumBytes: maximumBytes)
		}
		return data
	}
}
