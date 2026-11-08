// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameRuntime
import Foundation

/// A runtime manifest interface for runtime configuration tests.
package func makeRuntimeInterface(
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

/// One runtime lane pin for runtime configuration tests.
package func makeRuntimeLane(
	version: String = "1.0.0",
	url: String = "https://example.test/runtime.tar.gz",
	sha256: String = String(repeating: "a", count: 64),
	sizeBytes: Int = 4,
	minimumMacOS: String = "15.0",
	prefixRevision: Int = 2,
	interface: [String: Any] = makeRuntimeInterface()
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

/// A decoded runtime configuration with the published x86 lane and an unpublished ARM lane.
package func makeRuntimeConfiguration(
	schemaVersion: Int = 3,
	x86: [String: Any]? = makeRuntimeLane(),
	arm: [String: Any]? = makeRuntimeLane(
		version: "0.9.0+arm",
		url: "",
		sha256: "",
		sizeBytes: 0,
		minimumMacOS: "26.0",
		interface: makeRuntimeInterface(macDriver: "lib/wine/aarch64-unix/winemac.so")
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

/// Writes the minimal installed-runtime marker for a version and lane.
package func makeInstalledRuntime(
	version: String,
	lane: RuntimeLane,
	paths: AppPaths
) throws {
	let directory = paths.runtimeVersionDirectory(for: lane, version: version)
	try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
	try Data(#"{"architecture":"\#(lane.rawValue)"}"#.utf8).write(
		to: directory.appending(path: "RUNTIME.json"))
}
