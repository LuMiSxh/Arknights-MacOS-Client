// SPDX-License-Identifier: MPL-2.0

import CryptoKit
import Foundation
import Testing

@testable import ArknightsGameInstallation

/// Chunk sizes that are not multiples of eight split differently between the block and tail
/// loops, and must still agree with the reference digest on both the `Data` and pointer paths.
@Test(arguments: [0, 1, 3, 7, 8, 9, 15, 16, 17, 64, 1000])
func crc64MatchesXZReferenceVector(chunkSize: Int) {
	let reference = Data("123456789".utf8)
	var checksum = CRC64()
	var pointerChecksum = CRC64()
	var md5 = Insecure.MD5()
	let step = max(chunkSize, 1)
	var offset = 0
	while offset < reference.count {
		let chunk = reference[offset..<min(offset + step, reference.count)]
		checksum.update(chunk)
		chunk.withUnsafeBytes {
			pointerChecksum.update($0)
			md5.update(bufferPointer: $0)
		}
		offset += step
	}
	#expect(checksum.decimalString == "11051210869376104954")
	#expect(pointerChecksum.decimalString == "11051210869376104954")
	#expect(
		md5.finalize().map { String(format: "%02x", $0) }.joined()
			== "25f9e794323b453885f5181f1b624d0b")

	var empty = CRC64()
	Data().withUnsafeBytes { empty.update($0) }
	#expect(empty.decimalString == "0")
}

@Test
func authorizationHeaderMatchesOfficialLauncherAlgorithm() async throws {
	let api = LauncherAPI()
	let header = await api.authorizationHeader(region: .global, timestamp: 1_700_000_000)

	#expect(
		header
			== #"{"head":{"game_tag":"Arknights_EN","time":1700000000,"version":"1.8.1"},"sign":"59805376c0d7215967fbaf69ff8d2cc5"}"#
	)
}
