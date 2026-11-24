// SPDX-License-Identifier: MPL-2.0

import Compression
import Darwin
import Foundation

extension RuntimeArchive {
	private static let xzBufferSize = 256 * 1_024

	/// Streams an `.xz` file into a plain tar. Apple's `COMPRESSION_LZMA` reads the xz container.
	static func decompressXZ(at source: URL, to destination: URL) throws {
		let input = try FileHandle(forReadingFrom: source)
		let output = Darwin.open(
			destination.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC,
			S_IRUSR | S_IWUSR)
		guard output >= 0 else { throw POSIXError(.init(rawValue: errno) ?? .EIO) }
		defer { _ = close(output) }

		let inputBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: xzBufferSize)
		let outputBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: xzBufferSize)
		defer {
			inputBuffer.deallocate()
			outputBuffer.deallocate()
		}
		var stream = compression_stream(
			dst_ptr: outputBuffer, dst_size: 0, src_ptr: UnsafePointer(inputBuffer), src_size: 0,
			state: nil)
		guard
			compression_stream_init(&stream, COMPRESSION_STREAM_DECODE, COMPRESSION_LZMA)
				== COMPRESSION_STATUS_OK
		else {
			throw RuntimeArchiveError.decompressionFailed("could not initialize decompression")
		}
		defer { compression_stream_destroy(&stream) }

		var reachedEnd = false
		while true {
			if stream.src_size == 0, !reachedEnd {
				var count = 0
				while true {
					count = Darwin.read(input.fileDescriptor, inputBuffer, xzBufferSize)
					if count >= 0 { break }
					if errno == EINTR { continue }
					throw POSIXError(.init(rawValue: errno) ?? .EIO)
				}
				stream.src_ptr = UnsafePointer(inputBuffer)
				stream.src_size = count
				reachedEnd = count == 0
			}
			stream.dst_ptr = outputBuffer
			stream.dst_size = xzBufferSize
			let flags = reachedEnd ? Int32(COMPRESSION_STREAM_FINALIZE.rawValue) : 0
			let status = compression_stream_process(&stream, flags)
			let produced = xzBufferSize - stream.dst_size
			if produced > 0 {
				try writeAll(
					UnsafeRawBufferPointer(start: outputBuffer, count: produced), to: output)
			}
			switch status {
			case COMPRESSION_STATUS_END:
				return
			case COMPRESSION_STATUS_OK:
				// Finalizing with no input left and no output means the stream was cut short.
				if reachedEnd, produced == 0 {
					throw RuntimeArchiveError.decompressionFailed("truncated xz stream")
				}
			default:
				throw RuntimeArchiveError.decompressionFailed("corrupt xz stream")
			}
		}
	}
}
