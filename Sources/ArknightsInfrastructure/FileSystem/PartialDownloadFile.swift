// SPDX-License-Identifier: MPL-2.0

import Darwin
import Foundation

package enum PartialDownloadFileError: Error, Sendable {
	case unsafeFile(URL)
}

/// Opening and checking a resumable `.part` file. Both installers accept only a regular file with
/// one link, so a planted link cannot redirect a download.
package enum PartialDownloadFile {
	/// Checks an opened descriptor and returns its size. Closes the descriptor when it throws.
	package static func validatedSize(of descriptor: Int32, at url: URL) throws -> Int64 {
		var status = stat()
		guard fstat(descriptor, &status) == 0,
			status.st_mode & S_IFMT == S_IFREG,
			status.st_nlink == 1,
			status.st_size >= 0
		else {
			_ = close(descriptor)
			throw PartialDownloadFileError.unsafeFile(url)
		}
		return Int64(status.st_size)
	}

	/// Opens `url` read-write without following a link, creating it when missing.
	package static func open(at url: URL) throws -> (handle: FileHandle, size: Int64) {
		let descriptor = Darwin.open(
			url.path, O_RDWR | O_CREAT | O_NOFOLLOW | O_CLOEXEC, S_IRUSR | S_IWUSR)
		guard descriptor >= 0 else {
			if errno == ELOOP { throw PartialDownloadFileError.unsafeFile(url) }
			throw POSIXError(.init(rawValue: errno) ?? .EIO)
		}
		let size = try validatedSize(of: descriptor, at: url)
		return (FileHandle(fileDescriptor: descriptor, closeOnDealloc: true), size)
	}
}
