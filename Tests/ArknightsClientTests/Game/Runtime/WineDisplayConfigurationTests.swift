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
func metalFXUpscalingReplacesRetinaOnlyForScaledDisplays() {
	let upscaled = WineDisplayConfiguration(backingScaleFactor: 2, metalFXUpscaling: true)
	#expect(upscaled.metalFXUpscalingEnabled)
	#expect(!upscaled.retinaEnabled)
	#expect(upscaled.registryValue == "n")
	#expect(upscaled.browserScaleFactor == 1)
	#expect(
		!WineDisplayConfiguration(backingScaleFactor: 1, metalFXUpscaling: true)
			.metalFXUpscalingEnabled
	)
	#expect(
		!WineDisplayConfiguration(
			backingScaleFactor: 2,
			forceDisabled: true,
			metalFXUpscaling: true
		).metalFXUpscalingEnabled
	)
}

@Test(arguments: [
	(
		"global Mac Driver overrides the executable-specific value",
		"""
		[Software\\\\Wine\\\\AppDefaults\\\\Arknights.exe\\\\Mac Driver] 1786868781
		"RetinaMode"="n"

		[Software\\\\Wine\\\\Mac Driver] 1786868782
		"RetinaMode"="y"

		""",
		WineDisplayRegistryState(retinaMode: "y", logPixels: nil, usePreciseScrolling: nil)
	),
	(
		"Wine DPI comes from the desktop section",
		"""
		[Control Panel\\\\Desktop] 1786869739
		"LogPixels"=dword:000000c0

		[Software\\\\Wine\\\\Mac Driver] 1786868782
		"RetinaMode"="y"

		""",
		WineDisplayRegistryState(retinaMode: "y", logPixels: 192, usePreciseScrolling: nil)
	),
	(
		"precise scrolling comes from the global Mac Driver section",
		"""
		[Software\\\\Wine\\\\Mac Driver] 1786868782
		"UsePreciseScrolling"="n"

		""",
		WineDisplayRegistryState(retinaMode: nil, logPixels: nil, usePreciseScrolling: "n")
	),
])
func displayConfigurationReadsTheExpectedRegistryState(
	scenario: String,
	registry: String,
	expected: WineDisplayRegistryState
) throws {
	let prefix = try makeRegistryPrefix(registry)
	defer { try? FileManager.default.removeItem(at: prefix) }

	let configuration = WineDisplayConfiguration(backingScaleFactor: 2)
	#expect(configuration.registryState(in: prefix) == expected, Comment(rawValue: scenario))
	#expect(configuration.logPixels == 96)
	#expect(configuration.browserScaleFactor == 2)
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
