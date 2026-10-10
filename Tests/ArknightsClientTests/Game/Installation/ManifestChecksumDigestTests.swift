// SPDX-License-Identifier: MPL-2.0

import CryptoKit
import Foundation
import Testing

@testable import ArknightsClient

private func md5Hex(_ digest: some Digest) -> String {
	digest.map { String(format: "%02x", $0) }.joined()
}

@Suite("Manifest checksum digest paths")
struct ManifestChecksumDigestTests {
	@Test(arguments: [0, 1, 7, 8, 9, 63, 64, 65, 4096])
	func digestsMatchBetweenDataAndPointerPaths(size: Int) {
		let bytes = Data((0..<size).map { UInt8(truncatingIfNeeded: $0 &* 31 &+ 7) })

		var md5Data = Insecure.MD5()
		md5Data.update(data: bytes)
		var md5Pointer = Insecure.MD5()
		bytes.withUnsafeBytes { md5Pointer.update(bufferPointer: $0) }
		#expect(md5Hex(md5Data.finalize()) == md5Hex(md5Pointer.finalize()))

		var crcData = CRC64()
		crcData.update(bytes)
		var crcPointer = CRC64()
		bytes.withUnsafeBytes { crcPointer.update($0) }
		#expect(crcData.value == crcPointer.value)
	}

	@Test func md5PointerPathMatchesReferenceVectors() {
		var empty = Insecure.MD5()
		Data().withUnsafeBytes { empty.update(bufferPointer: $0) }
		#expect(md5Hex(empty.finalize()) == "d41d8cd98f00b204e9800998ecf8427e")

		var check = Insecure.MD5()
		Data("123456789".utf8).withUnsafeBytes { check.update(bufferPointer: $0) }
		#expect(md5Hex(check.finalize()) == "25f9e794323b453885f5181f1b624d0b")
	}

	@Test func crc64PointerPathMatchesXZReferenceVector() {
		var checksum = CRC64()
		Data("123456789".utf8).withUnsafeBytes { checksum.update($0) }
		#expect(checksum.decimalString == "11051210869376104954")

		var empty = CRC64()
		Data().withUnsafeBytes { empty.update($0) }
		#expect(empty.decimalString == "0")
	}
}
