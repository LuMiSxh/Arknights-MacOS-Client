// SPDX-License-Identifier: MPL-2.0

import CryptoKit
import Darwin
import Foundation

struct InstallerResumeMetadata: Codable, Sendable {
	let manifestHash: String
	let entityTag: String?
	let lastModified: String?

	var ifRangeValue: String? {
		guard let entityTag, !entityTag.hasPrefix("W/") else { return nil }
		return entityTag
	}

	func matchesEntity(_ response: InstallerResumeMetadata) -> Bool {
		(entityTag == nil || response.entityTag == nil || entityTag == response.entityTag)
			&& (lastModified == nil || response.lastModified == nil
				|| lastModified == response.lastModified)
	}

	func preservingValidatorsOmitted(by response: InstallerResumeMetadata)
		-> InstallerResumeMetadata
	{
		InstallerResumeMetadata(
			manifestHash: response.manifestHash,
			entityTag: response.entityTag ?? entityTag,
			lastModified: response.lastModified ?? lastModified
		)
	}
}

struct InstallerContentRange: Equatable, Sendable {
	let start: Int64
	let end: Int64
	let total: Int64

	var byteCount: Int64? {
		let (difference, underflow) = end.subtractingReportingOverflow(start)
		let (count, overflow) = difference.addingReportingOverflow(1)
		return underflow || overflow ? nil : count
	}

	static func parse(_ header: String?) -> InstallerContentRange? {
		guard let header else { return nil }
		let trimmed = header.trimmingCharacters(in: .whitespacesAndNewlines)
		guard trimmed.lowercased().hasPrefix("bytes ") else { return nil }
		let value = trimmed.dropFirst("bytes ".count)
		let components = value.split(separator: "/", omittingEmptySubsequences: false)
		guard components.count == 2,
			let total = decimal(components[1])
		else { return nil }
		let range = components[0].split(separator: "-", omittingEmptySubsequences: false)
		guard range.count == 2,
			let start = decimal(range[0]),
			let end = decimal(range[1]),
			start <= end,
			end < total
		else { return nil }
		return InstallerContentRange(start: start, end: end, total: total)
	}

	private static func decimal(_ value: Substring) -> Int64? {
		guard !value.isEmpty, value.allSatisfy({ $0 >= "0" && $0 <= "9" }) else { return nil }
		return Int64(value)
	}
}

extension GameInstaller {
	static func resumeMetadata(
		from response: HTTPURLResponse,
		manifestHash: String
	) throws -> InstallerResumeMetadata {
		func value(_ field: String) throws -> String? {
			guard let raw = response.value(forHTTPHeaderField: field) else { return nil }
			let header = raw.trimmingCharacters(in: .whitespacesAndNewlines)
			guard !header.isEmpty, header.utf8.count <= 4_096,
				!header.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
			else { throw LauncherError.invalidResponse }
			return header
		}
		return InstallerResumeMetadata(
			manifestHash: manifestHash,
			entityTag: try value("ETag"),
			lastModified: try value("Last-Modified")
		)
	}

	func resumeMetadataFile(
		for relativePath: String,
		in stagingDirectory: InstallerDirectoryHandle
	) -> InstallerFilePath {
		let digest = SHA256.hash(data: Data(relativePath.utf8))
			.map { String(format: "%02x", $0) }
			.joined()
		return stagingDirectory.file(named: "resume-\(digest).json")
	}

	func readResumeMetadata(
		at file: InstallerFilePath
	) throws -> InstallerResumeMetadata? {
		guard let status = try file.stat() else { return nil }
		guard status.st_mode & S_IFMT == S_IFREG, status.st_nlink == 1 else {
			throw LauncherError.unsafeInstallerTemporaryFile(file.url)
		}
		let descriptor = try file.open(flags: O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
		defer { _ = close(descriptor) }
		let data = try BoundedFileReader.readRegularFile(
			fileDescriptor: descriptor,
			at: file.url,
			maximumBytes: AppConstants.Game.installerResumeMetadataMaximumBytes
		)
		do {
			return try JSONDecoder().decode(InstallerResumeMetadata.self, from: data)
		} catch {
			log?.debug("Ignoring invalid installer resume metadata at \(file.url.path)")
			try file.unlink()
			return nil
		}
	}

	func writeResumeMetadata(
		_ metadata: InstallerResumeMetadata,
		to file: InstallerFilePath
	) throws {
		let encoder = JSONEncoder()
		encoder.outputFormatting = [.sortedKeys]
		var data = try encoder.encode(metadata)
		data.append(0x0A)
		guard data.count <= AppConstants.Game.installerResumeMetadataMaximumBytes else {
			throw LauncherError.invalidResponse
		}
		let temporary = file.directory.file(named: "metadata-\(UUID().uuidString).tmp")
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
					log?.error(
						"Failed to clean resume metadata temporary file: \(error.localizedDescription)"
					)
				}
			}
		}
		try Self.writeAll(data, to: descriptor)
		guard fsync(descriptor) == 0 else {
			throw POSIXError(.init(rawValue: errno) ?? .EIO)
		}
		guard
			renameat(
				file.directory.descriptor,
				temporary.name,
				file.directory.descriptor,
				file.name
			) == 0
		else {
			throw POSIXError(.init(rawValue: errno) ?? .EIO)
		}
		temporaryExists = false
		guard fsync(file.directory.descriptor) == 0 else {
			throw POSIXError(.init(rawValue: errno) ?? .EIO)
		}
	}

	private static func writeAll(_ data: Data, to descriptor: Int32) throws {
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
}
