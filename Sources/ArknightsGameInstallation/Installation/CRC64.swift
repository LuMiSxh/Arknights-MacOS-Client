// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation

// CRC-64/XZ, the checksum Yostar's manifest uses to verify each downloaded file.
struct CRC64: Sendable {
	private static let polynomial: UInt64 = 0xC96C_5795_D787_0F42

	// Slicing-by-8 tables, flattened to one array: entry `slice * 256 + index`. Slice 0 is the
	// bytewise table the tail loop uses; slice `n` carries that remainder `n` bytes further along,
	// so one pass folds eight input bytes.
	private static let table: [UInt64] = {
		var table = [UInt64](repeating: 0, count: 8 * 256)
		for index in 0..<256 {
			var value = UInt64(index)
			for _ in 0..<8 {
				value = value & 1 == 1 ? (value >> 1) ^ polynomial : value >> 1
			}
			table[index] = value
		}
		for slice in 1..<8 {
			for index in 0..<256 {
				let previous = table[(slice - 1) * 256 + index]
				table[slice * 256 + index] = table[Int(previous & 0xFF)] ^ (previous >> 8)
			}
		}
		return table
	}()

	private(set) var value = UInt64.max

	mutating func update(_ data: Data) {
		data.withUnsafeBytes { update($0) }
	}

	// Folds `bytes` into the running checksum. Callers may split the stream at any boundary.
	mutating func update(_ bytes: UnsafeRawBufferPointer) {
		guard let base = bytes.baseAddress else { return }
		var cursor = base.assumingMemoryBound(to: UInt8.self)
		var remaining = bytes.count
		var current = value
		Self.table.withUnsafeBufferPointer { table in
			// Reflected CRC-64: the block's lowest byte is the earliest one in the stream.
			while remaining >= 8 {
				let block = current ^ UInt64(littleEndian: loadUnalignedUInt64(from: cursor))
				current =
					table[7 * 256 + Int(block & 0xFF)]
					^ table[6 * 256 + Int((block >> 8) & 0xFF)]
					^ table[5 * 256 + Int((block >> 16) & 0xFF)]
					^ table[4 * 256 + Int((block >> 24) & 0xFF)]
					^ table[3 * 256 + Int((block >> 32) & 0xFF)]
					^ table[2 * 256 + Int((block >> 40) & 0xFF)]
					^ table[1 * 256 + Int((block >> 48) & 0xFF)]
					^ table[Int(block >> 56)]
				cursor = cursor.advanced(by: 8)
				remaining -= 8
			}
			while remaining > 0 {
				current =
					table[Int((current ^ UInt64(cursor.pointee)) & 0xFF)] ^ (current >> 8)
				cursor = cursor.advanced(by: 1)
				remaining -= 1
			}
		}
		value = current
	}

	var decimalString: String {
		String(~value)
	}
}

// `Data`'s bytes are not guaranteed to be aligned for a `UInt64` load.
private func loadUnalignedUInt64(from pointer: UnsafePointer<UInt8>) -> UInt64 {
	var block: UInt64 = 0
	withUnsafeMutableBytes(of: &block) { destination in
		destination.copyMemory(from: UnsafeRawBufferPointer(start: pointer, count: 8))
	}
	return block
}
