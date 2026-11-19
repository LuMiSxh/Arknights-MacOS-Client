// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsGameInstallation

/// Folders a user can pick for the Global server while the China server keeps its own folder.
enum ChosenFolder: CaseIterable {
	case emptyFolder, hiddenFilesOnly, unrelatedFiles, serverInstall, ownPartialFolder
	case otherServerFolder, insideOtherServer, containingOtherServer
	case launcherDataFolder, parentOfLauncherData, homeFolder

	/// Relative to the fixture root.
	var path: String {
		switch self {
		case .emptyFolder: "Picks/empty"
		case .hiddenFilesOnly: "Picks/hidden"
		case .unrelatedFiles: "Picks/files"
		case .serverInstall: "Picks/install"
		case .ownPartialFolder: "Games/global"
		case .otherServerFolder: "Games/china"
		case .insideOtherServer: "Games/china/sub"
		case .containingOtherServer: "Games"
		case .launcherDataFolder: "Support/ArknightsClient"
		case .parentOfLauncherData: "Support"
		case .homeFolder: "Home"
		}
	}

	var files: [String] {
		switch self {
		case .hiddenFilesOnly: [".DS_Store"]
		case .unrelatedFiles: ["notes.txt"]
		case .serverInstall: ["Arknights.exe", AppConstants.Game.installedStateFileName]
		case .ownPartialFolder: ["download.part"]
		default: []
		}
	}

	var expected: InstallDirectoryIssue? {
		switch self {
		case .emptyFolder, .hiddenFilesOnly, .serverInstall, .ownPartialFolder: nil
		case .unrelatedFiles: .hasFiles
		case .otherServerFolder, .insideOtherServer, .containingOtherServer:
			.overlapsOtherServer(.china)
		case .launcherDataFolder, .parentOfLauncherData, .homeFolder: .holdsLauncherData
		}
	}
}

struct InstallDirectoryPolicyTests {
	@Test(arguments: ChosenFolder.allCases)
	func flagsOnlyCollidingFolders(_ choice: ChosenFolder) throws {
		let storage = try TemporaryDirectory("InstallDirectoryPolicyTests")
		defer { storage.remove() }
		let root = storage.url
		let fileManager = FileManager.default
		let chosen = root.appending(path: choice.path, directoryHint: .isDirectory)
		try fileManager.createDirectory(at: chosen, withIntermediateDirectories: true)
		for name in choice.files {
			fileManager.createFile(atPath: chosen.appending(path: name).path, contents: Data())
		}

		let contents = try InstallDirectoryPolicy.inspect(chosen)
		let issue = InstallDirectoryPolicy.assess(
			candidate: chosen,
			region: .global,
			configuredDirectories: [
				.global: root.appending(path: "Games/global", directoryHint: .isDirectory),
				.china: root.appending(path: "Games/china", directoryHint: .isDirectory),
			],
			launcherDataRoot: root.appending(
				path: "Support/ArknightsClient", directoryHint: .isDirectory),
			homeDirectory: root.appending(path: "Home", directoryHint: .isDirectory),
			contents: contents
		)

		#expect(issue == choice.expected)
	}
}
