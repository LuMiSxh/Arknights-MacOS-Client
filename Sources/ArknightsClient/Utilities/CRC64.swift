// SPDX-License-Identifier: MPL-2.0

import Foundation

struct CRC64: Sendable {
	private static let polynomial: UInt64 = 0xC96C_5795_D787_0F42
	private static let table: [UInt64] = (0..<256).map { index in
		var value = UInt64(index)
		for _ in 0..<8 {
			value = value & 1 == 1 ? (value >> 1) ^ polynomial : value >> 1
		}
		return value
	}

	private(set) var value = UInt64.max

	mutating func update(_ data: Data) {
		for byte in data {
			let index = Int((value ^ UInt64(byte)) & 0xFF)
			value = Self.table[index] ^ (value >> 8)
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
			let data = try handle.read(upToCount: 1024 * 1024)
			guard let data, !data.isEmpty else { break }
			checksum.update(data)
		}
		return checksum.decimalString
	}
}
