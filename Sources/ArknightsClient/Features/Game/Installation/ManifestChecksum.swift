// SPDX-License-Identifier: MPL-2.0

import CryptoKit
import Foundation

enum ManifestChecksum {
	/// Hashes `url` with the algorithm implied by `expected`, honoring task cancellation between
	/// buffers and reporting each buffer's size through `onRead`.
	static func checksum(
		of url: URL,
		expected: String,
		onRead: ((Int) -> Void)? = nil
	) throws -> String {
		isMD5(expected)
			? try md5(of: url, onRead: onRead) : try CRC64.checksum(of: url, onRead: onRead)
	}

	static func matches(_ actual: String, expected: String) -> Bool {
		isMD5(expected)
			? actual.caseInsensitiveCompare(expected) == .orderedSame
			: actual == expected
	}

	private static func isMD5(_ value: String) -> Bool {
		value.count == 32 && value.allSatisfy(\.isHexDigit)
	}

	private static func md5(of url: URL, onRead: ((Int) -> Void)?) throws -> String {
		let handle = try FileHandle(forReadingFrom: url)
		defer {
			do {
				try handle.close()
			} catch {
				// The digest is already complete; close errors are not actionable here.
			}
		}
		var digest = Insecure.MD5()
		while true {
			try Task.checkCancellation()
			let data = try handle.read(upToCount: AppConstants.IO.checksumBufferSize)
			guard let data, !data.isEmpty else { break }
			digest.update(data: data)
			onRead?(data.count)
		}
		return digest.finalize().map { String(format: "%02x", $0) }.joined()
	}
}
