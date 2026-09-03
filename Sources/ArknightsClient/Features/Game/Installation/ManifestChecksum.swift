// SPDX-License-Identifier: MPL-2.0

import CryptoKit
import Foundation

enum ManifestChecksum {
	static func checksum(of url: URL, expected: String) throws -> String {
		isMD5(expected) ? try md5(of: url) : try CRC64.checksum(of: url)
	}

	static func matches(_ actual: String, expected: String) -> Bool {
		isMD5(expected)
			? actual.caseInsensitiveCompare(expected) == .orderedSame
			: actual == expected
	}

	private static func isMD5(_ value: String) -> Bool {
		value.count == 32 && value.allSatisfy(\.isHexDigit)
	}

	private static func md5(of url: URL) throws -> String {
		let handle = try FileHandle(forReadingFrom: url)
		var digest = Insecure.MD5()
		while true {
			let data = try handle.read(upToCount: AppConstants.IO.checksumBufferSize)
			guard let data, !data.isEmpty else { break }
			digest.update(data: data)
		}
		let checksum = digest.finalize().map { String(format: "%02x", $0) }.joined()
		try handle.close()
		return checksum
	}
}
