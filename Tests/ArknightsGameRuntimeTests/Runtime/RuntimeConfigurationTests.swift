// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation
import Testing

@testable import ArknightsGameRuntime

private func makeInterface(
	macDriver: String = "lib/wine/x86_64-unix/winemac.so",
	features: [String: Bool] = [
		"hardwareCursor": true,
		"metalFXSpatialUpscaling": true,
		"nativeFullscreenSpace": true,
	]
) -> [String: Any] {
	[
		"archive": ["wineDirectory": "Wine", "dxmtDirectory": "DXMT"],
		"executables": ["bin/wine64", "bin/wineserver"],
		"features": features,
		"requiredFiles": ["lib/wine/x86_64-unix/winemac.so"],
		"macDriver": macDriver,
		"launcher": ["path": "bin/Arknights", "target": "wine64"],
		"dxmt": [
			"payloadDirectory": "DXMT",
			"destinations": ["x64": "system32"],
			"libraries": ["d3d11.dll"],
		],
	]
}

private func lane(
	version: String = "1.0.0",
	url: String = "https://example.test/runtime.tar.gz",
	sha256: String = String(repeating: "a", count: 64),
	sizeBytes: Int = 4,
	minimumMacOS: String = "15.0",
	prefixRevision: Int = 2,
	interface: [String: Any] = makeInterface()
) -> [String: Any] {
	[
		"minimumMacOS": minimumMacOS,
		"prefixRevision": prefixRevision,
		"runtime": [
			"name": "Test Runtime",
			"version": version,
			"url": url,
			"sha256": sha256,
			"sizeBytes": sizeBytes,
		],
		"interface": interface,
		"components": ["wine": "11.17", "dxmt": "0.80"],
		"provenance": ["wineCommit": "e0aa380780b73e20fabcfe78fd42713b94929a53"],
	]
}

private func configuration(
	schemaVersion: Int = 3,
	x86: [String: Any]? = lane(),
	arm: [String: Any]? = lane(
		version: "0.9.0+arm",
		url: "",
		sha256: "",
		sizeBytes: 0,
		minimumMacOS: "26.0",
		interface: makeInterface(macDriver: "lib/wine/aarch64-unix/winemac.so")
	)
) throws -> RuntimeConfiguration {
	var lanes: [String: Any] = [:]
	if let x86 { lanes["x86"] = x86 }
	if let arm { lanes["arm"] = arm }
	let root: [String: Any] = [
		"schemaVersion": schemaVersion,
		"architecture": "x86",
		"prefixRevision": 2,
		"lanes": lanes,
	]
	return try JSONDecoder().decode(
		RuntimeConfiguration.self, from: JSONSerialization.data(withJSONObject: root))
}

struct RuntimeConfigurationTests {
	@Test
	func decodesBothLanePins() throws {
		let configuration = try configuration()

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
		var armLane = lane(
			version: "0.9.0+arm",
			url: "",
			sha256: "",
			sizeBytes: 0,
			minimumMacOS: "26.0",
			interface: makeInterface(macDriver: "lib/wine/aarch64-unix/winemac.so")
		)
		armLane["components"] = [String: Any]()
		armLane["provenance"] = [String: Any]()
		let configuration = try configuration(arm: armLane)

		let pin = try configuration.pinnedRuntime(for: .arm)
		#expect(!pin.isAvailable)
		#expect(pin.components?.wine == nil)
		#expect(pin.provenance?.wineCommit == nil)
	}

	@Test
	func rejectsAnAbsentLane() throws {
		let configuration = try configuration(arm: nil)

		#expect(throws: RuntimeConfigurationError.missingLane(.arm)) {
			_ = try configuration.pinnedRuntime(for: .arm)
		}
	}

	@Test
	func rejectsAnUnsupportedSchema() throws {
		let configuration = try configuration(schemaVersion: 2)

		#expect(throws: RuntimeConfigurationError.unsupportedSchema(2)) {
			_ = try configuration.pinnedRuntime(for: .x86)
		}
	}

	@Test
	func rejectsANonHTTPSArchiveURL() throws {
		let configuration = try configuration(
			x86: lane(url: "http://example.test/runtime.tar.gz"))

		#expect(throws: RuntimeConfigurationError.self) {
			_ = try configuration.pinnedRuntime(for: .x86)
		}
	}

	@Test
	func rejectsAMalformedChecksum() throws {
		let configuration = try configuration(x86: lane(sha256: "00"))

		#expect(throws: RuntimeConfigurationError.self) {
			_ = try configuration.pinnedRuntime(for: .x86)
		}
	}

	@Test
	func rejectsAnUnsafeInterfacePath() throws {
		var unsafe = makeInterface()
		unsafe["requiredFiles"] = ["C:/evil"]
		let configuration = try configuration(x86: lane(interface: unsafe))

		#expect(throws: RuntimeConfigurationError.self) {
			_ = try configuration.pinnedRuntime(for: .x86)
		}
	}

	@Test
	func decodesFeaturesAsBehaviorFlags() throws {
		let configuration = try configuration(
			x86: lane(
				interface: makeInterface(features: [
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
