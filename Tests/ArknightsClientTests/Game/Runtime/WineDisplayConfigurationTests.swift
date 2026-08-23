// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@Test
func displayConfigurationEnablesRetinaOnlyForScaledDisplays() {
	#expect(WineDisplayConfiguration(backingScaleFactor: 2).retinaEnabled)
	#expect(!WineDisplayConfiguration(backingScaleFactor: 1).retinaEnabled)
	#expect(
		!WineDisplayConfiguration(
			backingScaleFactor: 2,
			highResolutionEnabled: false
		).retinaEnabled
	)
	#expect(
		!WineDisplayConfiguration(backingScaleFactor: 2, forceDisabled: true).retinaEnabled
	)
}

@Test
func displayConfigurationReadsOnlyTheGlobalMacDriverValue() throws {
	let registry =
		"""
		[Software\\\\Wine\\\\AppDefaults\\\\Arknights.exe\\\\Mac Driver] 1786868781
		"RetinaMode"="n"

		[Software\\\\Wine\\\\Mac Driver] 1786868782
		"RetinaMode"="y"

		"""
	let prefix = try makeRegistryPrefix(registry)
	defer { try? FileManager.default.removeItem(at: prefix) }

	let state = WineDisplayConfiguration(backingScaleFactor: 2).registryState(in: prefix)
	#expect(state?.retinaMode == "y")
	#expect(state?.logPixels == nil)
	#expect(state?.usePreciseScrolling == nil)
}

@Test
func displayConfigurationReadsWineDPIFromTheDesktopSection() throws {
	let registry =
		"""
		[Control Panel\\\\Desktop] 1786869739
		"LogPixels"=dword:000000c0

		[Software\\\\Wine\\\\Mac Driver] 1786868782
		"RetinaMode"="y"

		"""
	let prefix = try makeRegistryPrefix(registry)
	defer { try? FileManager.default.removeItem(at: prefix) }

	let configuration = WineDisplayConfiguration(backingScaleFactor: 2)
	#expect(configuration.logPixels == 96)
	#expect(configuration.browserScaleFactor == 2)
	#expect(
		configuration.registryState(in: prefix)
			== WineDisplayRegistryState(
				retinaMode: "y",
				logPixels: 192,
				usePreciseScrolling: nil
			)
	)
}

@Test
func displayConfigurationReadsPreciseScrolling() throws {
	let registry =
		"""
		[Software\\\\Wine\\\\Mac Driver] 1786868782
		"UsePreciseScrolling"="n"

		"""
	let prefix = try makeRegistryPrefix(registry)
	defer { try? FileManager.default.removeItem(at: prefix) }

	let state = WineDisplayConfiguration(backingScaleFactor: 2).registryState(in: prefix)
	#expect(state?.usePreciseScrolling == "n")
}

private func makeRegistryPrefix(_ registry: String) throws -> URL {
	let prefix = FileManager.default.temporaryDirectory.appending(
		path: "wine-registry-test-\(UUID().uuidString)",
		directoryHint: .isDirectory
	)
	try FileManager.default.createDirectory(at: prefix, withIntermediateDirectories: true)
	try registry.write(
		to: prefix.appending(path: "user.reg"),
		atomically: true,
		encoding: .utf8
	)
	return prefix
}
