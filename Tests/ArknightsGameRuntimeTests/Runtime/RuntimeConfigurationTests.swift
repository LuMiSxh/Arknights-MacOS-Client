// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsRuntimeTestSupport
import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsGameRuntime

struct RuntimeConfigurationTests {
	@Test
	func decodesBothLanePins() throws {
		let configuration = try makeRuntimeConfiguration(
			x86: makeRuntimeLane(deltas: [
				[
					"from": "0.9.0", "url": "https://example.test/delta.tar.xz",
					"sha256": String(repeating: "b", count: 64), "sizeBytes": 2,
				]
			]))

		let x86 = try configuration.pinnedRuntime(for: .x86)
		#expect(x86.lane == .x86)
		#expect(x86.version == "1.0.0")
		#expect(x86.url?.absoluteString == "https://example.test/runtime.tar.xz")
		#expect(x86.deltas.map(\.from) == ["0.9.0"])
		#expect(x86.deltas.first?.asset.sizeBytes == 2)
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
		#expect(arm.deltas.isEmpty)
	}

	@Test
	func rejectsAnUnsupportedSchema() throws {
		let configuration = try makeRuntimeConfiguration(schemaVersion: 2)

		#expect(throws: RuntimeConfigurationError.unsupportedSchema(2)) {
			_ = try configuration.pinnedRuntime(for: .x86)
		}
	}

	@Test(arguments: InvalidLaneConfiguration.allCases)
	private func rejectsAnInvalidLaneConfiguration(scenario: InvalidLaneConfiguration) throws {
		let configuration = try scenario.configuration()

		#expect(throws: RuntimeConfigurationError.self) {
			_ = try configuration.pinnedRuntime(for: .x86)
		}
	}

	private enum InvalidLaneConfiguration: CaseIterable, Sendable {
		case nonHTTPSArchiveURL
		case malformedChecksum
		case unsafeInterfacePath
		case nonHTTPSDeltaURL

		func configuration() throws -> RuntimeConfiguration {
			switch self {
			case .nonHTTPSArchiveURL:
				return try makeRuntimeConfiguration(
					x86: makeRuntimeLane(url: "http://example.test/runtime.tar.xz"))
			case .malformedChecksum:
				return try makeRuntimeConfiguration(x86: makeRuntimeLane(sha256: "00"))
			case .unsafeInterfacePath:
				var unsafe = makeRuntimeInterface()
				unsafe["requiredFiles"] = ["C:/evil"]
				return try makeRuntimeConfiguration(
					x86: makeRuntimeLane(interface: unsafe))
			case .nonHTTPSDeltaURL:
				return try makeRuntimeConfiguration(
					x86: makeRuntimeLane(deltas: [
						[
							"from": "0.9.0", "url": "http://example.test/delta.tar.xz",
							"sha256": String(repeating: "b", count: 64), "sizeBytes": 2,
						]
					]))
			}
		}
	}
}
