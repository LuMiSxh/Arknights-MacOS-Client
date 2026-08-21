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
	let fileManager = FileManager.default
	let prefix = fileManager.temporaryDirectory.appending(
		path: "retina-registry-test-\(UUID().uuidString)",
		directoryHint: .isDirectory
	)
	defer { try? fileManager.removeItem(at: prefix) }
	try fileManager.createDirectory(at: prefix, withIntermediateDirectories: true)
	let registry =
		"""
		[Software\\\\Wine\\\\AppDefaults\\\\Arknights.exe\\\\Mac Driver] 1786868781
		"RetinaMode"="n"

		[Software\\\\Wine\\\\Mac Driver] 1786868782
		"RetinaMode"="y"

		"""
	try registry.write(
		to: prefix.appending(path: "user.reg"),
		atomically: true,
		encoding: .utf8
	)

	let state = WineDisplayConfiguration(backingScaleFactor: 2).registryState(in: prefix)
	#expect(state?.retinaMode == "y")
	#expect(state?.logPixels == nil)
	#expect(state?.usePreciseScrolling == nil)
}

@Test
func displayConfigurationReadsWineDPIFromTheDesktopSection() throws {
	let fileManager = FileManager.default
	let prefix = fileManager.temporaryDirectory.appending(
		path: "dpi-registry-test-\(UUID().uuidString)",
		directoryHint: .isDirectory
	)
	defer { try? fileManager.removeItem(at: prefix) }
	try fileManager.createDirectory(at: prefix, withIntermediateDirectories: true)
	let registry =
		"""
		[Control Panel\\\\Desktop] 1786869739
		"LogPixels"=dword:000000c0

		[Software\\\\Wine\\\\Mac Driver] 1786868782
		"RetinaMode"="y"

		"""
	try registry.write(
		to: prefix.appending(path: "user.reg"),
		atomically: true,
		encoding: .utf8
	)

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
	let fileManager = FileManager.default
	let prefix = fileManager.temporaryDirectory.appending(
		path: "scrolling-registry-test-\(UUID().uuidString)",
		directoryHint: .isDirectory
	)
	defer { try? fileManager.removeItem(at: prefix) }
	try fileManager.createDirectory(at: prefix, withIntermediateDirectories: true)
	let registry =
		"""
		[Software\\\\Wine\\\\Mac Driver] 1786868782
		"UsePreciseScrolling"="n"

		"""
	try registry.write(
		to: prefix.appending(path: "user.reg"),
		atomically: true,
		encoding: .utf8
	)

	let state = WineDisplayConfiguration(backingScaleFactor: 2).registryState(in: prefix)
	#expect(state?.usePreciseScrolling == "n")
}
