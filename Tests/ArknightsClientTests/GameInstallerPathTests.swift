// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

struct GameInstallerPathTests {
	private let installer = GameInstaller(api: PathTestAPI())

	@Test
	func manifestRejectsEmptyPathComponents() {
		for path in ["/bin/game.dat", "bin//game.dat", "bin/game.dat/"] {
			#expect(throws: LauncherError.self) {
				_ = try GameInstaller.safeRelativePath(path)
			}
		}
	}

	@Test
	func manifestRejectsCaseInsensitiveDuplicatePaths() {
		let manifest = makeManifest(paths: ["bin/Game.dat", "BIN/game.dat"])

		#expect(throws: LauncherError.self) {
			try installer.validateManifest(manifest, inside: temporaryInstallDirectory())
		}
	}

	@Test
	func manifestRejectsFileDirectoryConflicts() {
		let manifest = makeManifest(paths: ["assets", "assets/image.png"])

		#expect(throws: LauncherError.self) {
			try installer.validateManifest(manifest, inside: temporaryInstallDirectory())
		}
	}

	@Test
	func installerRejectsSymbolicLinkBeforeDownloading() async throws {
		let fileManager = FileManager.default
		let root = temporaryInstallDirectory()
		let outside = root.deletingLastPathComponent().appending(
			path: "GameInstallerPathTests-outside-\(UUID().uuidString)",
			directoryHint: .isDirectory
		)
		defer {
			try? fileManager.removeItem(at: root)
			try? fileManager.removeItem(at: outside)
		}
		try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
		try fileManager.createDirectory(at: outside, withIntermediateDirectories: true)
		try fileManager.createSymbolicLink(
			at: root.appending(path: "bin"),
			withDestinationURL: outside
		)
		let manifest = makeManifest(paths: ["bin/game.dat"])
		let installer = GameInstaller(api: PathTestAPI(manifest: manifest))

		do {
			_ = try await installer.install(
				configuration: PathTestAPI.configuration, region: .global, into: root,
				progress: { _ in })
			Issue.record("Expected the symbolic destination to be rejected")
		} catch LauncherError.symbolicLinkInInstallPath(let url) {
			#expect(url.lastPathComponent == "bin")
		} catch {
			Issue.record("Unexpected installer error: \(error)")
		}
		#expect(!fileManager.fileExists(atPath: outside.appending(path: "game.dat").path))
	}

	@Test
	func installerRejectsSymbolicPartialFileWithoutTouchingItsTarget() async throws {
		let fileManager = FileManager.default
		let root = temporaryInstallDirectory()
		let outside = root.deletingLastPathComponent().appending(
			path: "GameInstallerPathTests-partial-\(UUID().uuidString)"
		)
		defer {
			try? fileManager.removeItem(at: root)
			try? fileManager.removeItem(at: outside)
		}
		let binDirectory = root.appending(path: "bin", directoryHint: .isDirectory)
		try fileManager.createDirectory(at: binDirectory, withIntermediateDirectories: true)
		let sentinel = Data("outside".utf8)
		try sentinel.write(to: outside)
		try fileManager.createSymbolicLink(
			at: binDirectory.appending(path: "game.dat.part"),
			withDestinationURL: outside
		)
		let installer = GameInstaller(api: PathTestAPI())

		do {
			_ = try await installer.install(
				configuration: PathTestAPI.configuration, region: .global, into: root,
				progress: { _ in })
			Issue.record("Expected the symbolic partial file to be rejected")
		} catch LauncherError.symbolicLinkInInstallPath(let url) {
			#expect(url.lastPathComponent == "game.dat.part")
		} catch {
			Issue.record("Unexpected installer error: \(error)")
		}
		#expect(try Data(contentsOf: outside) == sentinel)
	}

	@Test
	func installerRejectsSymbolicDestinationWithoutTouchingItsTarget() async throws {
		let fileManager = FileManager.default
		let root = temporaryInstallDirectory()
		let outside = root.deletingLastPathComponent().appending(
			path: "GameInstallerPathTests-destination-\(UUID().uuidString)"
		)
		defer {
			try? fileManager.removeItem(at: root)
			try? fileManager.removeItem(at: outside)
		}
		let binDirectory = root.appending(path: "bin", directoryHint: .isDirectory)
		try fileManager.createDirectory(at: binDirectory, withIntermediateDirectories: true)
		let sentinel = Data("outside".utf8)
		try sentinel.write(to: outside)
		try fileManager.createSymbolicLink(
			at: binDirectory.appending(path: "game.dat"),
			withDestinationURL: outside
		)
		let installer = GameInstaller(api: PathTestAPI())

		do {
			_ = try await installer.install(
				configuration: PathTestAPI.configuration, region: .global, into: root,
				progress: { _ in })
			Issue.record("Expected the symbolic destination file to be rejected")
		} catch LauncherError.symbolicLinkInInstallPath(let url) {
			#expect(url.lastPathComponent == "game.dat")
		} catch {
			Issue.record("Unexpected installer error: \(error)")
		}
		#expect(try Data(contentsOf: outside) == sentinel)
	}

	@Test
	func installerRejectsMultiplyLinkedPartialFileWithoutWritingToItsPeer() async throws {
		let fileManager = FileManager.default
		let root = temporaryInstallDirectory()
		let outside = root.deletingLastPathComponent().appending(
			path: "GameInstallerPathTests-hardlink-\(UUID().uuidString)"
		)
		defer {
			try? fileManager.removeItem(at: root)
			try? fileManager.removeItem(at: outside)
		}
		let binDirectory = root.appending(path: "bin", directoryHint: .isDirectory)
		try fileManager.createDirectory(at: binDirectory, withIntermediateDirectories: true)
		let sentinel = Data("outside".utf8)
		try sentinel.write(to: outside)
		try fileManager.linkItem(
			at: outside,
			to: binDirectory.appending(path: "game.dat.part")
		)
		let manifest = GameManifest(
			source: "payload",
			file: [ManifestFile(path: "bin/game.dat", hash: "0", size: "16")]
		)
		let installer = GameInstaller(api: PathTestAPI(manifest: manifest))

		do {
			_ = try await installer.install(
				configuration: PathTestAPI.configuration, region: .global, into: root,
				progress: { _ in })
			Issue.record("Expected the multiply linked partial file to be rejected")
		} catch LauncherError.unsafeInstallerTemporaryFile(let url) {
			#expect(url.lastPathComponent == "game.dat.part")
		} catch {
			Issue.record("Unexpected installer error: \(error)")
		}
		#expect(try Data(contentsOf: outside) == sentinel)
	}

	private func makeManifest(paths: [String]) -> GameManifest {
		GameManifest(
			source: "payload",
			file: paths.map { ManifestFile(path: $0, hash: "0", size: "0") }
		)
	}

	private func temporaryInstallDirectory() -> URL {
		FileManager.default.temporaryDirectory.appending(
			path: "GameInstallerPathTests-\(UUID().uuidString)",
			directoryHint: .isDirectory
		)
	}
}

private struct PathTestAPI: LauncherAPIProviding {
	static let configuration = GameConfiguration(
		gameLowestVersion: "1.0.0",
		gameLatestVersion: "1.0.0",
		gameLatestFilePath: "manifest.json",
		gameStartExeName: "Arknights",
		gameStartParams: [],
		gameUninstallScript: "uninstall.exe",
		decompressionSize: "1 MB"
	)

	let manifest: GameManifest

	init(
		manifest: GameManifest = GameManifest(
			source: "payload",
			file: [ManifestFile(path: "bin/game.dat", hash: "0", size: "0")]
		)
	) {
		self.manifest = manifest
	}

	func gameConfiguration(region: GameRegion) async throws -> GameConfiguration {
		Self.configuration
	}

	func branding(region: GameRegion) async throws -> LauncherBranding {
		throw CancellationError()
	}

	func cdnConfiguration(region: GameRegion) async throws -> CDNConfiguration {
		let url = URL(string: "https://download.test/")!
		return CDNConfiguration(primaryCdn: url, backUpCdn: url)
	}

	func manifest(
		for configuration: GameConfiguration,
		region: GameRegion
	) async throws -> GameManifest {
		manifest
	}
}
