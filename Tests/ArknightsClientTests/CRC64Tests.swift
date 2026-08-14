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
  let header = await api.authorizationHeader(timestamp: 1_700_000_000)

  #expect(
    header
      == #"{"head":{"game_tag":"Arknights_EN","time":1700000000,"version":"1.8.1"},"sign":"59805376c0d7215967fbaf69ff8d2cc5"}"#
  )
}
