// SPDX-License-Identifier: MPL-2.0

import Foundation

extension GameInstaller {
	func saveState(
		configuration: GameConfiguration,
		manifest: GameManifest,
		to installDirectory: URL
	) throws {
		let state = InstalledState(
			version: configuration.gameLatestVersion,
			basis: configuration.gameLatestFilePath,
			source: manifest.source,
			installedAt: Date(),
			files: manifest.file
		)
		let encoder = JSONEncoder()
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
		encoder.dateEncodingStrategy = .iso8601
		try encoder.encode(state).write(
			to: installDirectory.appending(path: ".arknights-client-state.json"),
			options: .atomic
		)
	}

	func loadState(from installDirectory: URL) -> InstalledState? {
		let url = installDirectory.appending(path: ".arknights-client-state.json")
		guard let data = try? Data(contentsOf: url) else { return nil }
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .iso8601
		return try? decoder.decode(InstalledState.self, from: data)
	}

	func excludeFromBackup(_ directory: URL) {
		var directory = directory
		var values = URLResourceValues()
		values.isExcludedFromBackup = true
		try? directory.setResourceValues(values)
	}
}
