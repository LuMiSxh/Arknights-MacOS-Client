// SPDX-License-Identifier: MPL-2.0

import Foundation

/// ECMA-182 CRC-64, the checksum Yostar's manifest uses to verify each downloaded file.
struct CRC64: Sendable {
	private static let polynomial: UInt64 = 0xC96C_5795_D787_0F42

	/// Slicing-by-8 tables. Table 0 is the bytewise table the tail loop uses; table `slice`
	/// carries that remainder `slice` bytes further along, so one pass folds eight input bytes.
	private static let tables: [[UInt64]] = {
		var tables = [[UInt64]](repeating: [UInt64](repeating: 0, count: 256), count: 8)
		for index in 0..<256 {
			var value = UInt64(index)
			for _ in 0..<8 {
				value = value & 1 == 1 ? (value >> 1) ^ polynomial : value >> 1
			}
			tables[0][index] = value
		}
		for slice in 1..<8 {
			for index in 0..<256 {
				let previous = tables[slice - 1][index]
				tables[slice][index] = tables[0][Int(previous & 0xFF)] ^ (previous >> 8)
			}
		}
		return tables
	}()

	private(set) var value = UInt64.max

	mutating func update(_ data: Data) {
		data.withUnsafeBytes { rawBuffer in
			let bytes = rawBuffer.bindMemory(to: UInt8.self)
			guard var cursor = bytes.baseAddress else { return }
			var remaining = bytes.count
			var current = value
			Self.tables.withUnsafeBufferPointer { tables in
				// Reflected CRC-64: the block's lowest byte is the earliest one in the stream.
				while remaining >= 8 {
					let block = current ^ UInt64(littleEndian: loadUnalignedUInt64(from: cursor))
					current =
						tables[7][Int(block & 0xFF)]
						^ tables[6][Int((block >> 8) & 0xFF)]
						^ tables[5][Int((block >> 16) & 0xFF)]
						^ tables[4][Int((block >> 24) & 0xFF)]
						^ tables[3][Int((block >> 32) & 0xFF)]
						^ tables[2][Int((block >> 40) & 0xFF)]
						^ tables[1][Int((block >> 48) & 0xFF)]
						^ tables[0][Int(block >> 56)]
					cursor = cursor.advanced(by: 8)
					remaining -= 8
				}
				while remaining > 0 {
					current =
						tables[0][Int((current ^ UInt64(cursor.pointee)) & 0xFF)] ^ (current >> 8)
					cursor = cursor.advanced(by: 1)
					remaining -= 1
				}
			}
			value = current
		}
	}

	var decimalString: String {
		String(~value)
	}

	static func checksum(of url: URL) throws -> String {
		let handle = try FileHandle(forReadingFrom: url)
		defer {
			do {
				try handle.close()
			} catch {
				// The read result is already complete; close errors are not actionable here.
			}
		}

		var checksum = CRC64()
		while true {
			let data = try handle.read(upToCount: AppConstants.IO.checksumBufferSize)
			guard let data, !data.isEmpty else { break }
			checksum.update(data)
		}
		return checksum.decimalString
	}
}

/// `Data`'s bytes are not guaranteed to be aligned for a `UInt64` load.
private func loadUnalignedUInt64(from pointer: UnsafePointer<UInt8>) -> UInt64 {
	var block: UInt64 = 0
	withUnsafeMutableBytes(of: &block) { destination in
		destination.copyMemory(from: UnsafeRawBufferPointer(start: pointer, count: 8))
	}
	return block
}
