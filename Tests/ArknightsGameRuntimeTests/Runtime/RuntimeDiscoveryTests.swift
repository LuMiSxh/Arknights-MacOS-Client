// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsGameInstallation
@testable import ArknightsGameRuntime

struct RuntimeDiscoveryTests {
	@Test
	func launchResolvesThePinnedVersionDirectoryInsteadOfTheNewestInstall() throws {
		let temporary = try TemporaryDirectory("RuntimeDiscoveryTests")
		defer { temporary.remove() }
		let paths = AppPaths(
			applicationSupportDirectory: temporary.url,
			runtimeSelection: RuntimeSelection(selected: .x86))
		let configuration = try makeRuntimeConfiguration(x86: makeRuntimeLane(version: "2.0.0"))
		try makeInstalledRuntime(version: "1.0.0", lane: .x86, paths: paths)

		let directory = try GameSessionController.pinnedRuntimeVersionDirectory(
			paths: paths, configuration: configuration)

		#expect(directory == paths.runtimeVersionDirectory(for: .x86, version: "2.0.0"))
	}

	@Test
	func launchRefusesWhenOnlyAnOlderRuntimeIsInstalled() throws {
		let temporary = try TemporaryDirectory("RuntimeDiscoveryTests")
		defer { temporary.remove() }
		let paths = AppPaths(
			applicationSupportDirectory: temporary.url,
			runtimeSelection: RuntimeSelection(selected: .x86))
		let configuration = try makeRuntimeConfiguration(x86: makeRuntimeLane(version: "2.0.0"))
		try makeInstalledRuntime(version: "1.0.0", lane: .x86, paths: paths)

		do {
			_ = try GameSessionController.discoverRuntime(
				paths: paths,
				configuration: configuration,
				compatibilityManager: GameCompatibilityManager())
			Issue.record("Runtime discovery should refuse an outdated runtime")
		} catch let error as WineRuntimeDiscoveryError {
			guard case .missingRuntime(let url) = error else {
				Issue.record("Unexpected discovery error: \(error)")
				return
			}
			#expect(url == paths.runtimeVersionDirectory(for: .x86, version: "2.0.0"))
		}
	}
}
