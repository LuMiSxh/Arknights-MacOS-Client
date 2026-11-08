// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsGameRuntime

struct RuntimeConfigurationTests {
	@Test
	func decodesBothLanePins() throws {
		let configuration = try makeRuntimeConfiguration()

		let x86 = try configuration.pinnedRuntime(for: .x86)
		#expect(x86.lane == .x86)
		#expect(x86.version == "1.0.0")
		#expect(x86.url?.absoluteString == "https://example.test/runtime.tar.gz")
		#expect(x86.sizeBytes == 4)
		#expect(x86.minimumMacOS.majorVersion == 15)
		#expect(x86.prefixRevision == 2)
		#expect(x86.interface.dxmt.payloadDirectory == "DXMT")
		#expect(
			x86.features
				== RuntimeFeatures(
					hardwareCursor: true, metalFXSpatialUpscaling: true, nativeFullscreenSpace: true
				))
		#expect(x86.isAvailable)

		let arm = try configuration.pinnedRuntime(for: .arm)
		#expect(arm.lane == .arm)
		#expect(arm.version == "0.9.0+arm")
		#expect(arm.minimumMacOS.majorVersion == 26)
		#expect(!arm.isAvailable)
	}

	@Test
	func decodesAnUnpublishedLaneWithEmptyComponentsAndProvenance() throws {
		var armLane = makeRuntimeLane(
			version: "0.9.0+arm",
			url: "",
			sha256: "",
			sizeBytes: 0,
			minimumMacOS: "26.0",
			interface: makeRuntimeInterface(macDriver: "lib/wine/aarch64-unix/winemac.so")
		)
		armLane["components"] = [String: Any]()
		armLane["provenance"] = [String: Any]()
		let configuration = try makeRuntimeConfiguration(arm: armLane)

		let pin = try configuration.pinnedRuntime(for: .arm)
		#expect(!pin.isAvailable)
		#expect(pin.components?.wine == nil)
		#expect(pin.provenance?.wineCommit == nil)
	}

	@Test
	func rejectsAnAbsentLane() throws {
		let configuration = try makeRuntimeConfiguration(arm: nil)

		#expect(throws: RuntimeConfigurationError.missingLane(.arm)) {
			_ = try configuration.pinnedRuntime(for: .arm)
		}
	}

	@Test
	func rejectsAnUnsupportedSchema() throws {
		let configuration = try makeRuntimeConfiguration(schemaVersion: 2)

		#expect(throws: RuntimeConfigurationError.unsupportedSchema(2)) {
			_ = try configuration.pinnedRuntime(for: .x86)
		}
	}

	@Test
	func rejectsANonHTTPSArchiveURL() throws {
		let configuration = try makeRuntimeConfiguration(
			x86: makeRuntimeLane(url: "http://example.test/runtime.tar.gz"))

		#expect(throws: RuntimeConfigurationError.self) {
			_ = try configuration.pinnedRuntime(for: .x86)
		}
	}

	@Test
	func rejectsAMalformedChecksum() throws {
		let configuration = try makeRuntimeConfiguration(x86: makeRuntimeLane(sha256: "00"))

		#expect(throws: RuntimeConfigurationError.self) {
			_ = try configuration.pinnedRuntime(for: .x86)
		}
	}

	@Test
	func rejectsAnUnsafeInterfacePath() throws {
		var unsafe = makeRuntimeInterface()
		unsafe["requiredFiles"] = ["C:/evil"]
		let configuration = try makeRuntimeConfiguration(x86: makeRuntimeLane(interface: unsafe))

		#expect(throws: RuntimeConfigurationError.self) {
			_ = try configuration.pinnedRuntime(for: .x86)
		}
	}

	@Test
	func decodesFeaturesAsBehaviorFlags() throws {
		let configuration = try makeRuntimeConfiguration(
			x86: makeRuntimeLane(
				interface: makeRuntimeInterface(features: [
					"hardwareCursor": false,
					"metalFXSpatialUpscaling": true,
					"nativeFullscreenSpace": false,
				])))

		let pin = try configuration.pinnedRuntime(for: .x86)
		#expect(!pin.features.hardwareCursor)
		#expect(pin.features.metalFXSpatialUpscaling)
		#expect(!pin.features.nativeFullscreenSpace)
	}
}
