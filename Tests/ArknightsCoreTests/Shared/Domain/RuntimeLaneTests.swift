// SPDX-License-Identifier: MPL-2.0

import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsCore

@Test
func bundledLaneReadsTheManifestArchitecture() throws {
	let temporary = try TemporaryDirectory("RuntimeLaneTests")
	defer { temporary.remove() }
	try Data(
		#"{"architecture":"arm","interface":{"macDriver":"lib/wine/x86_64-unix/winemac.so"}}"#
			.utf8
	).write(to: temporary.url.appending(path: "RUNTIME.json"))

	let result = RuntimeLane.bundled(resourceDirectory: temporary.url)

	#expect(result.lane == .arm)
	#expect(result.diagnostic == nil)
}

@Test
func bundledLaneFallsBackToTheWineDriver() throws {
	let temporary = try TemporaryDirectory("RuntimeLaneDriverTests")
	defer { temporary.remove() }
	try Data(
		#"{"interface":{"macDriver":"lib/wine/aarch64-unix/winemac.so"}}"#.utf8
	).write(to: temporary.url.appending(path: "RUNTIME.json"))

	#expect(RuntimeLane.bundled(resourceDirectory: temporary.url).lane == .arm)
}

@Test
func missingManifestUsesTheX86Lane() throws {
	let temporary = try TemporaryDirectory("RuntimeLaneMissingTests")
	defer { temporary.remove() }

	let missing = RuntimeLane.bundled(resourceDirectory: temporary.url)
	#expect(missing.lane == .x86)
	#expect(missing.diagnostic == nil)
	#expect(RuntimeLane.bundled(resourceDirectory: nil).lane == .x86)
}

@Test
func manifestWithoutALaneReportsADiagnostic() throws {
	let temporary = try TemporaryDirectory("RuntimeLaneDiagnosticTests")
	defer { temporary.remove() }
	try Data(#"{"interface":{}}"#.utf8).write(
		to: temporary.url.appending(path: "RUNTIME.json"))

	let result = RuntimeLane.bundled(resourceDirectory: temporary.url)

	#expect(result.lane == .x86)
	#expect(result.diagnostic != nil)
}

@Test
func declaredLanePrefersTheExplicitArchitecture() {
	#expect(
		RuntimeLane.declared(
			architecture: "arm",
			macDriver: "lib/wine/x86_64-unix/winemac.so",
			runtimeName: ""
		) == .arm)
	#expect(
		RuntimeLane.declared(
			architecture: nil,
			macDriver: "lib/wine/aarch64-unix/winemac.so",
			runtimeName: ""
		) == .arm)
	#expect(
		RuntimeLane.declared(
			architecture: nil,
			macDriver: nil,
			runtimeName: "Arknights macOS Runtime (aarch64 canary)"
		) == .arm)
	#expect(
		RuntimeLane.declared(architecture: nil, macDriver: nil, runtimeName: "Runtime") == nil)
}
