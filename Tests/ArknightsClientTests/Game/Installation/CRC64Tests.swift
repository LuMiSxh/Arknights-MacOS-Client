// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@Test
func crc64MatchesECMAReferenceVector() {
	var checksum = CRC64()
	checksum.update(Data("123456789".utf8))

	#expect(checksum.decimalString == "11051210869376104954")
}

@Test
func crc64SupportsIncrementalUpdates() {
	var checksum = CRC64()
	checksum.update(Data("1234".utf8))
	checksum.update(Data("56789".utf8))

	#expect(checksum.decimalString == "11051210869376104954")
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

/// Chunk boundaries that are not multiples of eight split differently between the block and
/// tail loops, and must still agree with the single-shot digest.
@Test(arguments: [1, 3, 7, 8, 9, 15, 16, 17, 64])
func crc64IsIndependentOfChunkBoundaries(chunkSize: Int) {
	var generator = SystemRandomNumberGenerator()
	let bytes = Data((0..<1000).map { _ in UInt8.random(in: .min ... .max, using: &generator) })

	var whole = CRC64()
	whole.update(bytes)

	var chunked = CRC64()
	var offset = 0
	while offset < bytes.count {
		let end = min(offset + chunkSize, bytes.count)
		chunked.update(bytes[offset..<end])
		offset = end
	}

	#expect(chunked.decimalString == whole.decimalString)
}
