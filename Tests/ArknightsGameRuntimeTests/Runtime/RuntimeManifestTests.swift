// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation
import Testing

@testable import ArknightsGameRuntime

private func manifestData(
	architecture: String?,
	macDriver: String = "lib/wine/aarch64-unix/winemac.so"
) throws -> Data {
	var root: [String: Any] = [
		"prefixRevision": 2,
		"runtime": [
			"name": "Test Runtime",
			"version": "1.0.0",
			"sha256": String(repeating: "a", count: 64),
			"sizeBytes": 4,
		],
		"interface": [
			"archive": ["wineDirectory": "Wine", "dxmtDirectory": "DXMT"],
			"executables": ["bin/wine64", "bin/wineserver"],
			"features": [
				"hardwareCursor": true,
				"metalFXSpatialUpscaling": false,
				"nativeFullscreenSpace": false,
			],
			"requiredFiles": ["lib/wine/aarch64-unix/winemac.so"],
			"macDriver": macDriver,
			"launcher": ["path": "bin/Arknights", "target": "wine64"],
			"dxmt": [
				"payloadDirectory": "DXMT",
				"destinations": ["x64": "system32"],
				"libraries": ["d3d11.dll"],
			],
		],
	]
	if let architecture {
		root["architecture"] = architecture
	}
	return try JSONSerialization.data(withJSONObject: root)
}

struct RuntimeManifestTests {
	@Test
	func decodesTheExplicitArchitecture() throws {
		let data = try manifestData(architecture: "arm")
		let manifest = try JSONDecoder().decode(RuntimeManifest.self, from: data)

		#expect(manifest.architecture == .arm)
		#expect(manifest.revision == "\(String(repeating: "a", count: 64))-prefix-2")
		#expect(manifest.interface.dxmt.payloadDirectory == "DXMT")
		#expect(manifest.interface.dxmtPayloadFiles == ["DXMT/x64/d3d11.dll"])
	}

	@Test
	func doesNotInferTheLaneFromTheDriverOrRuntimeName() {
		#expect(throws: DecodingError.self) {
			let data = try manifestData(architecture: nil)
			_ = try JSONDecoder().decode(RuntimeManifest.self, from: data)
		}
	}

	@Test
	func rejectsAnUnknownArchitecture() {
		#expect(throws: DecodingError.self) {
			let data = try manifestData(
				architecture: "aarch64", macDriver: "lib/wine/x86_64-unix/winemac.so")
			_ = try JSONDecoder().decode(RuntimeManifest.self, from: data)
		}
	}

	@Test
	func aStaleDriverCannotOverrideTheDeclaredLane() throws {
		let data = try manifestData(
			architecture: "x86", macDriver: "lib/wine/aarch64-unix/winemac.so")
		let manifest = try JSONDecoder().decode(RuntimeManifest.self, from: data)

		#expect(manifest.architecture == .x86)
	}
}
