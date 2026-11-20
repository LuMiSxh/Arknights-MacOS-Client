// SPDX-License-Identifier: MPL-2.0

import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsCore

private func access(macOS major: Int) -> RuntimeAccess {
	RuntimeAccess(
		macOSVersion: OperatingSystemVersion(majorVersion: major, minorVersion: 0, patchVersion: 0)
	)
}

struct RuntimeSelectionStoreTests {
	@Test(
		arguments: [
			(15, RuntimeLane.x86),
			(26, RuntimeLane.x86),
			(28, RuntimeLane.arm),
		]
	)
	func freshSelectionUsesTheOSDefault(major: Int, expected: RuntimeLane) throws {
		let temporary = try TemporaryDirectory("RuntimeSelectionStoreDefaultTests")
		defer { temporary.remove() }
		let store = RuntimeSelectionStore(
			fileURL: temporary.url.appending(path: "runtime-selection.json"))

		#expect(try store.load().effectiveLane(access: access(macOS: major)) == expected)
	}

	@Test
	func aValidOverrideWinsAndADisallowedOverrideFallsBackToTheDefault() throws {
		let temporary = try TemporaryDirectory("RuntimeSelectionStoreOverrideTests")
		defer { temporary.remove() }
		let store = RuntimeSelectionStore(
			fileURL: temporary.url.appending(path: "runtime-selection.json"))
		try store.save(RuntimeSelection(override: .x86))

		let selection = try store.load()
		#expect(selection.effectiveLane(access: access(macOS: 27)) == .x86)
		#expect(selection.effectiveLane(access: access(macOS: 28)) == .arm)
		#expect(selection.validOverride(access: access(macOS: 28)) == nil)
	}

	/// A launcher before 1.0.1 persisted its lane in `selected`. That value pinned users to a lane
	/// that fails on their macOS, so it must never count as a choice.
	@Test
	func aLegacySelectedLaneIsIgnoredAsAChoice() throws {
		let temporary = try TemporaryDirectory("RuntimeSelectionStoreLegacyTests")
		defer { temporary.remove() }
		let url = temporary.url.appending(path: "runtime-selection.json")
		try Data(#"{"selected":"arm","installed":{"arm":"1.0.0"}}"#.utf8).write(to: url)

		let selection = try RuntimeSelectionStore(fileURL: url).load()

		#expect(selection.effectiveLane(access: access(macOS: 26)) == .x86)
		#expect(selection.installedVersion(for: .arm) == "1.0.0")
	}

	@Test
	func installedVersionsRoundTripAsAJSONObject() throws {
		let temporary = try TemporaryDirectory("RuntimeSelectionStoreVersionsTests")
		defer { temporary.remove() }
		let url = temporary.url.appending(path: "runtime-selection.json")
		let store = RuntimeSelectionStore(fileURL: url)
		try store.save(
			RuntimeSelection(
				override: .arm,
				installedVersions: [.x86: "1.0.0", .arm: "1.0.0-rc1"]))

		let loaded = try store.load()
		#expect(loaded.override == .arm)
		#expect(loaded.installedVersion(for: .x86) == "1.0.0")
		#expect(loaded.installedVersion(for: .arm) == "1.0.0-rc1")
		let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
		let root = try #require(object as? [String: Any])
		let installed = try #require(root["installed"] as? [String: String])
		#expect(installed == ["x86": "1.0.0", "arm": "1.0.0-rc1"])
	}
}
