// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsInfrastructure
import Foundation

package struct InstallationStateRequest: Sendable {
	let selectedRegion: GameRegion
	let selectedDirectory: URL
	let regionDirectories: [GameRegion: URL]
}

package struct InstallationStateSnapshot: Sendable {
	package let installPresence: InstallPresence
	package let installedRegions: [GameRegion]
	let diagnostic: String?
}

enum InstallationStateReader {
	// Runs the blocking file reads off the caller's actor; the reader observes the caller's
	// cancellation through `Task.checkCancellation()`.
	@concurrent
	static func loadOffCaller(
		_ request: InstallationStateRequest
	) async throws -> InstallationStateSnapshot {
		try load(request)
	}

	static func load(
		_ request: InstallationStateRequest,
		fileManager: FileManager = .default
	) throws -> InstallationStateSnapshot {
		try Task.checkCancellation()
		let stateURL = request.selectedDirectory.appending(
			path: AppConstants.Game.installedStateFileName)
		let executableURL = request.selectedDirectory.appending(path: "Arknights.exe")
		let hasExecutable = fileManager.fileExists(atPath: executableURL.path)
		var installedState: InstalledState?
		var diagnostic: String?

		do {
			installedState = try JSONFileStore.installedState.read(
				InstalledState.self, at: stateURL)
			try Task.checkCancellation()
		} catch is CancellationError {
			throw CancellationError()
		} catch let error as POSIXError where error.code == .ENOENT {
			installedState = nil
		} catch {
			diagnostic =
				"Installed state is unreadable at \(stateURL.path): \(error.localizedDescription)"
		}

		let installPresence: InstallPresence
		if hasExecutable, let installedState {
			installPresence = .installed(version: installedState.version)
		} else if try containsPartialDownload(
			in: request.selectedDirectory,
			fileManager: fileManager
		) {
			installPresence = .partialDownload
		} else {
			installPresence = .absent
		}
		let installedRegions = try GameRegion.allCases.filter { region in
			try Task.checkCancellation()
			if region == request.selectedRegion { return installPresence.isInstalled }
			guard let directory = request.regionDirectories[region] else { return false }
			return fileManager.fileExists(
				atPath: directory.appending(path: "Arknights.exe").path
			)
				&& fileManager.fileExists(
					atPath: directory.appending(
						path: AppConstants.Game.installedStateFileName
					).path
				)
		}

		return InstallationStateSnapshot(
			installPresence: installPresence,
			installedRegions: installedRegions,
			diagnostic: diagnostic
		)
	}

	private static func containsPartialDownload(
		in directory: URL,
		fileManager: FileManager
	) throws -> Bool {
		guard
			let enumerator = fileManager.enumerator(
				at: directory,
				includingPropertiesForKeys: [.isSymbolicLinkKey],
				options: [.skipsPackageDescendants]
			)
		else { return false }
		for case let file as URL in enumerator {
			try Task.checkCancellation()
			if try file.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink == true {
				enumerator.skipDescendants()
				continue
			}
			if file.pathExtension == "part" { return true }
		}
		return false
	}
}
