// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@MainActor
struct IntegrationTestEnvironment {
	let root: URL
	let paths: AppPaths
	let defaults: UserDefaults
	let preferences: LauncherPreferencesStore
	let session: URLSession

	private let defaultsSuiteName: String

	init() throws {
		let identifier = UUID().uuidString
		root = FileManager.default.temporaryDirectory.appending(
			path: "ArknightsClientIntegrationTests-\(identifier)",
			directoryHint: .isDirectory
		)
		let applicationSupport = root.appending(
			path: "Application Support",
			directoryHint: .isDirectory
		)
		let caches = root.appending(path: "Caches", directoryHint: .isDirectory)
		let library = root.appending(path: "Library", directoryHint: .isDirectory)
		try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
		paths = AppPaths(
			applicationSupportDirectory: applicationSupport,
			cachesDirectory: caches,
			libraryDirectory: library
		)

		defaultsSuiteName = "ArknightsClientIntegrationTests.\(identifier)"
		guard let defaults = UserDefaults(suiteName: defaultsSuiteName) else {
			throw IntegrationTestEnvironmentError.cannotCreatePreferences(defaultsSuiteName)
		}
		defaults.removePersistentDomain(forName: defaultsSuiteName)
		self.defaults = defaults
		preferences = LauncherPreferencesStore(defaults: defaults)

		let configuration = URLSessionConfiguration.ephemeral
		configuration.protocolClasses = [LocalFixtureURLProtocol.self]
		session = URLSession(configuration: configuration)
	}

	func cleanUp() {
		session.invalidateAndCancel()
		defaults.removePersistentDomain(forName: defaultsSuiteName)
		do {
			try FileManager.default.removeItem(at: root)
		} catch CocoaError.fileNoSuchFile {
			return
		} catch {
			Issue.record("Could not remove integration test directory: \(error)")
		}
	}
}

private enum IntegrationTestEnvironmentError: Error {
	case cannotCreatePreferences(String)
}
