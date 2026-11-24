// SPDX-License-Identifier: MPL-2.0

import Compression
import Foundation

/// Compresses `data` into an `.xz` stream, so archive tests need no external tool.
package func xzCompressed(_ data: Data) -> Data {
	let capacity = data.count + data.count / 2 + 4_096
	var output = Data(count: capacity)
	let written = output.withUnsafeMutableBytes { destination in
		data.withUnsafeBytes { source in
			compression_encode_buffer(
				destination.bindMemory(to: UInt8.self).baseAddress!, capacity,
				source.bindMemory(to: UInt8.self).baseAddress
					?? UnsafePointer(bitPattern: 1)!,
				data.count, nil, COMPRESSION_LZMA)
		}
	}
	precondition(written > 0, "xz compression failed")
	return output.prefix(written)
}
