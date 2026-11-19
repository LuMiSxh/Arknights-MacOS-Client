// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation

/// Why a folder picked for a server's game files needs a refusal or a confirmation.
package enum InstallDirectoryIssue: Equatable, Sendable {
	/// The folder overlaps the install location of another server.
	case overlapsOtherServer(GameRegion)
	/// The folder is, or contains, the launcher's own data.
	case holdsLauncherData
	/// The folder has files and is not an existing install of this server.
	case hasFiles

	/// A refused folder cannot be used. The user must choose another one.
	package var isRefusal: Bool {
		switch self {
		case .overlapsOtherServer, .holdsLauncherData: true
		case .hasFiles: false
		}
	}
}

/// A folder the user picked that needs a refusal or a confirmation before use.
package struct PendingInstallDirectory: Equatable, Sendable {
	package let url: URL
	package let issue: InstallDirectoryIssue
}

/// What the launcher sees in a folder before it classifies the folder.
struct InstallFolderContents: Equatable, Sendable {
	/// No visible entries. Hidden files such as `.DS_Store` do not count.
	let isEmpty: Bool
	/// The executable and installed state that mark an existing install of a server.
	let hasServerInstall: Bool
}

/// Decides whether a folder can hold one server's game files directly.
enum InstallDirectoryPolicy {
	static func inspect(
		_ folder: URL,
		fileManager: FileManager = .default
	) throws -> InstallFolderContents {
		guard fileManager.fileExists(atPath: folder.path) else {
			return InstallFolderContents(isEmpty: true, hasServerInstall: false)
		}
		let entries = try fileManager.contentsOfDirectory(
			at: folder,
			includingPropertiesForKeys: nil,
			options: [.skipsHiddenFiles]
		)
		let hasExecutable = fileManager.fileExists(
			atPath: folder.appending(path: "Arknights.exe").path)
		let hasState = fileManager.fileExists(
			atPath: folder.appending(path: AppConstants.Game.installedStateFileName).path)
		return InstallFolderContents(
			isEmpty: entries.isEmpty,
			hasServerInstall: hasExecutable && hasState
		)
	}

	/// Returns the issue to show, or `nil` when the folder can be used as it is.
	static func assess(
		candidate: URL,
		region: GameRegion,
		configuredDirectories: [GameRegion: URL],
		launcherDataRoot: URL,
		homeDirectory: URL,
		contents: InstallFolderContents
	) -> InstallDirectoryIssue? {
		let folder = canonical(candidate)
		if let ownDirectory = configuredDirectories[region], canonical(ownDirectory) == folder {
			return nil
		}
		for other in GameRegion.allCases where other != region {
			guard let directory = configuredDirectories[other] else { continue }
			let otherFolder = canonical(directory)
			if isAncestorOrSelf(folder, of: otherFolder)
				|| isAncestorOrSelf(otherFolder, of: folder)
			{
				return .overlapsOtherServer(other)
			}
		}
		if isAncestorOrSelf(folder, of: canonical(launcherDataRoot))
			|| folder == canonical(homeDirectory)
		{
			return .holdsLauncherData
		}
		if !contents.isEmpty && !contents.hasServerInstall {
			return .hasFiles
		}
		return nil
	}

	private static func canonical(_ url: URL) -> URL {
		url.resolvingSymlinksInPath().standardizedFileURL
	}

	private static func isAncestorOrSelf(_ ancestor: URL, of url: URL) -> Bool {
		let ancestorComponents = ancestor.pathComponents
		let components = url.pathComponents
		return ancestorComponents.count <= components.count
			&& Array(components.prefix(ancestorComponents.count)) == ancestorComponents
	}
}
