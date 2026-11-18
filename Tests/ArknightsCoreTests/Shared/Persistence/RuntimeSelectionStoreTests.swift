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
			(26, RuntimeLane.arm),
			(27, RuntimeLane.arm),
			(28, RuntimeLane.arm),
			(29, RuntimeLane.arm),
		]
	)
	func freshSelectionUsesTheOSDefault(major: Int, expected: RuntimeLane) throws {
		let temporary = try TemporaryDirectory("RuntimeSelectionStoreDefaultTests")
		defer { temporary.remove() }
		let store = RuntimeSelectionStore(
			fileURL: temporary.url.appending(path: "runtime-selection.json"))

		#expect(try store.load(access: access(macOS: major)).selected == expected)
	}

	@Test
	func persistedSelectionWinsOverTheOSDefault() throws {
		let temporary = try TemporaryDirectory("RuntimeSelectionStorePersistedTests")
		defer { temporary.remove() }
		let store = RuntimeSelectionStore(
			fileURL: temporary.url.appending(path: "runtime-selection.json"))
		try store.save(RuntimeSelection(selected: .x86))

		#expect(try store.load(access: access(macOS: 28)).selected == .x86)
	}

	@Test
	func installedVersionsRoundTripAsAJSONObject() throws {
		let temporary = try TemporaryDirectory("RuntimeSelectionStoreVersionsTests")
		defer { temporary.remove() }
		let url = temporary.url.appending(path: "runtime-selection.json")
		let store = RuntimeSelectionStore(fileURL: url)
		try store.save(
			RuntimeSelection(
				selected: .arm,
				installedVersions: [.x86: "1.0.0", .arm: "1.0.0-rc1"]))

		let loaded = try store.load()
		#expect(loaded.selected == .arm)
		#expect(loaded.installedVersion(for: .x86) == "1.0.0")
		#expect(loaded.installedVersion(for: .arm) == "1.0.0-rc1")
		let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
		let root = try #require(object as? [String: Any])
		let installed = try #require(root["installed"] as? [String: String])
		#expect(installed == ["x86": "1.0.0", "arm": "1.0.0-rc1"])
	}
}
