// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsCustomization
import Darwin
import Foundation
import Testing

@testable import ArknightsGameInstallation
@testable import ArknightsInfrastructure

struct GameInstallerPathTests {
	private let installer = GameInstaller(
		api: PathTestAPI(),
		compatibilityManager: GameCompatibilityManager()
	)

	@Test
	func manifestRejectsUnsafePathComponents() throws {
		for path in [
			"", "/", "//bin/game.dat", "bin//game.dat", "bin/game.dat/", ".",
			"../game.dat", "bin/../game.dat", "bin\\game.dat", "bin/game\n.dat",
		] {
			#expect(throws: InstallerError.self) {
				_ = try GameInstaller.safeRelativePath(path)
			}
		}

		// The official manifest prefixes paths with a single slash.
		#expect(try GameInstaller.safeRelativePath("/bin/game.dat") == "bin/game.dat")
		try validateManifest(
			GameManifest(
				source: "/Arknights_JP-36.7.23-game",
				file: [ManifestFile(path: "/Arknights.exe", hash: "0", size: "0")]
			))

		let invalidFileSets: [[String]] = [
			["bin/Game.dat", "BIN/game.dat"],
			["assets", "assets/image.png"],
			["assets", "assets-foo", "assets/image.png"],
			["foo", "foo.part"],
			["foo", "foo.part/content"],
			[AppConstants.Game.installedStateFileName],
			[AppConstants.Game.installedStateFileName + "/content"],
			["bin/\(AppConstants.Game.installerStagingDirectoryName)/content"],
		]
		for paths in invalidFileSets {
			#expect(throws: InstallerError.self) {
				try validateManifest(makeManifest(paths: paths))
			}
		}
	}

	enum UnsafeLink: CaseIterable {
		case symlinkedSourceDirectory
		case symlinkedPartialFile
		case symlinkedDestinationFile
		case hardLinkedPartialFile
		case boundedReader
	}

	@Test(arguments: UnsafeLink.allCases)
	func installerRejectsSymbolicPartialFileWithoutTouchingItsTarget(link: UnsafeLink) async throws
	{
		if link == .boundedReader {
			try assertBoundedReaderRejectsUnsafeInputs()
			return
		}
		let fileManager = FileManager.default
		let root = temporaryInstallDirectory()
		let outside = root.deletingLastPathComponent().appending(
			path: "GameInstallerPathTests-outside-\(UUID().uuidString)"
		)
		defer {
			try? fileManager.removeItem(at: root)
			try? fileManager.removeItem(at: outside)
		}
		let binDirectory = root.appending(path: "bin", directoryHint: .isDirectory)
		let sentinel = Data("outside".utf8)
		var manifest = GameManifest(
			source: "payload",
			file: [ManifestFile(path: "bin/game.dat", hash: "0", size: "0")]
		)
		var rejectedName = "game.dat"
		var untouched = outside
		switch link {
		case .symlinkedSourceDirectory:
			try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
			try fileManager.createDirectory(at: outside, withIntermediateDirectories: true)
			try fileManager.createSymbolicLink(at: binDirectory, withDestinationURL: outside)
			rejectedName = "bin"
			untouched = outside.appending(path: "game.dat")
		case .symlinkedPartialFile:
			try fileManager.createDirectory(at: binDirectory, withIntermediateDirectories: true)
			try sentinel.write(to: outside)
			try fileManager.createSymbolicLink(
				at: binDirectory.appending(path: "game.dat.part"), withDestinationURL: outside)
			rejectedName = "game.dat.part"
		case .symlinkedDestinationFile:
			try fileManager.createDirectory(at: binDirectory, withIntermediateDirectories: true)
			try sentinel.write(to: outside)
			try fileManager.createSymbolicLink(
				at: binDirectory.appending(path: "game.dat"), withDestinationURL: outside)
		case .hardLinkedPartialFile:
			try fileManager.createDirectory(at: binDirectory, withIntermediateDirectories: true)
			try sentinel.write(to: outside)
			try fileManager.linkItem(at: outside, to: binDirectory.appending(path: "game.dat.part"))
			manifest = GameManifest(
				source: "payload",
				file: [ManifestFile(path: "bin/game.dat", hash: "0", size: "16")]
			)
			rejectedName = "game.dat.part"
		case .boundedReader:
			return
		}
		let installer = GameInstaller(
			api: PathTestAPI(manifest: manifest),
			compatibilityManager: GameCompatibilityManager()
		)

		do {
			_ = try await installer.install(
				configuration: PathTestAPI.configuration, region: .global, into: root,
				progress: { _ in })
			Issue.record("Expected \(link) to be rejected")
		} catch InstallerError.symbolicLinkInInstallPath(let url) {
			#expect(link != .hardLinkedPartialFile)
			#expect(url.lastPathComponent == rejectedName)
		} catch InstallerError.unsafeInstallerTemporaryFile(let url) {
			#expect(link == .hardLinkedPartialFile)
			#expect(url.lastPathComponent == rejectedName)
		} catch {
			Issue.record("Unexpected installer error: \(error)")
		}
		if link == .symlinkedSourceDirectory {
			#expect(!fileManager.fileExists(atPath: untouched.path))
		} else {
			#expect(try Data(contentsOf: untouched) == sentinel)
		}
	}

	private func assertBoundedReaderRejectsUnsafeInputs() throws {
		let root = FileManager.default.temporaryDirectory.appending(
			path: "bounded-reader-\(UUID().uuidString)", directoryHint: .isDirectory)
		let target = root.appending(path: "target")
		let link = root.appending(path: "link")
		try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
		defer { try? FileManager.default.removeItem(at: root) }
		try Data(repeating: 0, count: 16).write(to: target)
		try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
		#expect(throws: Error.self) {
			_ = try BoundedFileReader.readRegularFile(at: target, maximumBytes: 8)
		}
		#expect(throws: Error.self) {
			_ = try BoundedFileReader.readRegularFile(at: link, maximumBytes: 32)
		}

		let fifo = root.appending(path: "fifo")
		guard mkfifo(fifo.path, 0o600) == 0 else {
			throw POSIXError(.init(rawValue: errno) ?? .EIO)
		}
		let started = DispatchSemaphore(value: 0)
		let finished = DispatchSemaphore(value: 0)
		try withInstallLease(at: root) { lease in
			let install = lease.directory
			DispatchQueue.global().async {
				started.signal()
				do {
					_ = try BoundedFileReader.readRegularFile(at: fifo, maximumBytes: 32)
				} catch {
					// A FIFO is rejected after its nonblocking descriptor is inspected.
				}
				do {
					let descriptor = try install.file(at: "fifo").open(flags: O_RDONLY | O_CLOEXEC)
					_ = close(descriptor)
				} catch {
					// Descriptor-anchored file opens also reject FIFOs without waiting for a writer.
				}
				finished.signal()
			}
			#expect(started.wait(timeout: .now() + .seconds(1)) == .success)
			let returnedBeforeWriter =
				finished.wait(timeout: .now() + .milliseconds(400)) == .success
			if !returnedBeforeWriter {
				DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(450)) {
					let writer = open(fifo.path, O_WRONLY | O_NONBLOCK | O_CLOEXEC)
					if writer >= 0 { _ = close(writer) }
				}
				#expect(finished.wait(timeout: .now() + .seconds(2)) == .success)
			}
			#expect(returnedBeforeWriter)
		}
	}

	private func validateManifest(_ manifest: GameManifest) throws {
		let root = temporaryInstallDirectory()
		defer { try? FileManager.default.removeItem(at: root) }
		try withInstallLease(at: root) { lease in
			try installer.validateManifest(manifest, in: lease.directory)
		}
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
		let url = URL(string: "https://download.yo-star.com/")!
		return CDNConfiguration(primaryCdn: url, backUpCdn: url)
	}

	func manifest(
		for configuration: GameConfiguration,
		region: GameRegion
	) async throws -> GameManifest {
		manifest
	}
}
