// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsInfrastructure
import Darwin
import Foundation

extension JSONFileStore {
	static let installedState = JSONFileStore(
		maximumBytes: AppConstants.Game.installedStateMaximumBytes,
		iso8601Dates: true
	)
}

extension GameInstaller {
	func saveState(
		configuration: GameConfiguration,
		manifest: GameManifest,
		to installDirectory: InstallerDirectory
	) throws {
		let state = InstalledState(
			version: configuration.gameLatestVersion,
			basis: configuration.gameLatestFilePath,
			source: manifest.source,
			installedAt: Date(),
			files: manifest.file
		)
		let temporary = try stagingDirectory(in: installDirectory)
			.file(named: "state-\(UUID().uuidString).tmp")
		do {
			try JSONFileStore.installedState.writeDurably(
				state,
				to: installDirectory.file(named: AppConstants.Game.installedStateFileName),
				temporary: temporary
			)
		} catch JSONFileStoreError.tooLarge {
			throw LauncherError.invalidResponse
		}
	}

	func loadState(from installDirectory: InstallerDirectory) throws -> InstalledState? {
		let file = installDirectory.file(named: AppConstants.Game.installedStateFileName)
		guard try file.stat() != nil else { return nil }
		let descriptor = try file.open(flags: O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
		defer { _ = close(descriptor) }
		return try JSONFileStore.installedState.read(
			InstalledState.self,
			fileDescriptor: descriptor,
			at: file.url
		)
	}

	func excludeFromBackup(_ directory: URL) throws {
		var directory = directory
		var values = URLResourceValues()
		values.isExcludedFromBackup = true
		try directory.setResourceValues(values)
	}
}
