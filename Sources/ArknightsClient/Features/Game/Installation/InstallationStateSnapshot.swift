// SPDX-License-Identifier: MPL-2.0

import Foundation

struct InstallationStateRequest: Sendable {
	let selectedRegion: GameRegion
	let selectedDirectory: URL
	let regionDirectories: [GameRegion: URL]
}

struct InstallationStateSnapshot: Sendable {
	let isInstalled: Bool
	let hasPartialDownload: Bool
	let installedVersion: String?
	let installedRegions: [GameRegion]
	let diagnostic: String?
}

enum InstallationStateReader {
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
			let data = try BoundedFileReader.readRegularFile(
				at: stateURL, maximumBytes: AppConstants.Game.installedStateMaximumBytes)
			try Task.checkCancellation()
			let decoder = JSONDecoder()
			decoder.dateDecodingStrategy = .iso8601
			installedState = try decoder.decode(InstalledState.self, from: data)
		} catch is CancellationError {
			throw CancellationError()
		} catch let error as POSIXError where error.code == .ENOENT {
			installedState = nil
		} catch {
			diagnostic =
				"Installed state is unreadable at \(stateURL.path): \(error.localizedDescription)"
		}

		let isInstalled = hasExecutable && installedState != nil
		let hasPartialDownload: Bool
		if isInstalled {
			hasPartialDownload = false
		} else {
			hasPartialDownload = try containsPartialDownload(
				in: request.selectedDirectory,
				fileManager: fileManager
			)
		}
		let installedRegions = try GameRegion.allCases.filter { region in
			try Task.checkCancellation()
			if region == request.selectedRegion { return isInstalled }
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
			isInstalled: isInstalled,
			hasPartialDownload: hasPartialDownload,
			installedVersion: installedState?.version,
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
