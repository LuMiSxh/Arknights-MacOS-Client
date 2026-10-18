// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsLauncherUI

@MainActor
struct IntegrationTestEnvironment {
	let root: URL
	let paths: AppPaths
	let defaults: UserDefaults
	let preferences: LauncherPreferencesStore
	let session: URLSession
	let route = StubURLProtocol.Route()

	private let storage: TemporaryDirectory
	private let defaultsSuiteName: String

	init() throws {
		storage = try TemporaryDirectory("ArknightsClientIntegrationTests")
		root = storage.url
		let applicationSupport = root.appending(
			path: "Application Support",
			directoryHint: .isDirectory
		)
		let caches = root.appending(path: "Caches", directoryHint: .isDirectory)
		let library = root.appending(path: "Library", directoryHint: .isDirectory)
		paths = AppPaths(
			applicationSupportDirectory: applicationSupport,
			cachesDirectory: caches,
			libraryDirectory: library
		)

		let isolated = makeIsolatedDefaults("ArknightsClientIntegrationTests")
		defaults = isolated.defaults
		defaultsSuiteName = isolated.suiteName
		preferences = LauncherPreferencesStore(defaults: defaults)
		session = route.session
	}

	func cleanUp() {
		session.invalidateAndCancel()
		defaults.removePersistentDomain(forName: defaultsSuiteName)
		storage.remove()
	}
}
