// SPDX-License-Identifier: MPL-2.0

extension Sequence where Element == UInt8 {
	var hexString: String {
		let digits = Array("0123456789abcdef".utf8)
		var encoded: [UInt8] = []
		encoded.reserveCapacity(underestimatedCount * 2)
		for byte in self {
			encoded.append(digits[Int(byte >> 4)])
			encoded.append(digits[Int(byte & 0x0F)])
		}
		return String(decoding: encoded, as: UTF8.self)
	}
}
