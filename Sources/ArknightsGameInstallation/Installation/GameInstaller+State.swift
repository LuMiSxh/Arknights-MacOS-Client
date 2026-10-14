// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsInfrastructure
import Darwin
import Foundation

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
		let encoder = JSONEncoder()
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
		encoder.dateEncodingStrategy = .iso8601
		var data = try encoder.encode(state)
		data.append(0x0A)
		guard data.count <= AppConstants.Game.installedStateMaximumBytes else {
			throw LauncherError.invalidResponse
		}
		let temporary = try stagingDirectory(in: installDirectory)
			.file(named: "state-\(UUID().uuidString).tmp")
		let descriptor = try temporary.open(
			flags: O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW,
			mode: S_IRUSR | S_IWUSR
		)
		var temporaryExists = true
		defer {
			_ = close(descriptor)
			if temporaryExists {
				do {
					try temporary.unlink()
				} catch {
					// A failed cleanup cannot make an incomplete state file authoritative.
				}
			}
		}
		try Self.write(data, to: descriptor)
		guard fsync(descriptor) == 0 else {
			throw POSIXError(.init(rawValue: errno) ?? .EIO)
		}
		let stateFile = installDirectory.file(named: AppConstants.Game.installedStateFileName)
		try temporary.rename(to: stateFile)
		temporaryExists = false
		try stateFile.synchronizeParent()
	}

	func loadState(from installDirectory: InstallerDirectory) throws -> InstalledState? {
		let file = installDirectory.file(named: AppConstants.Game.installedStateFileName)
		guard try file.stat() != nil else { return nil }
		let descriptor = try file.open(flags: O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
		defer { _ = close(descriptor) }
		let data = try BoundedFileReader.readRegularFile(
			fileDescriptor: descriptor,
			at: file.url,
			maximumBytes: AppConstants.Game.installedStateMaximumBytes
		)
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .iso8601
		return try decoder.decode(InstalledState.self, from: data)
	}

	private static func write(_ data: Data, to descriptor: Int32) throws {
		try data.withUnsafeBytes { buffer in
			guard let baseAddress = buffer.baseAddress else { return }
			var offset = 0
			while offset < buffer.count {
				let count = Darwin.write(
					descriptor,
					baseAddress.advanced(by: offset),
					buffer.count - offset
				)
				if count < 0 {
					if errno == EINTR { continue }
					throw POSIXError(.init(rawValue: errno) ?? .EIO)
				}
				guard count > 0 else { throw POSIXError(.EIO) }
				offset += count
			}
		}
	}

	func excludeFromBackup(_ directory: URL) throws {
		var directory = directory
		var values = URLResourceValues()
		values.isExcludedFromBackup = true
		try directory.setResourceValues(values)
	}
}
