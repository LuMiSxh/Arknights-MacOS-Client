// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsInfrastructure
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

	func preservingValidatorsOmitted(
		by response: InstallerResumeMetadata
	)
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
				header.rangeOfCharacter(from: .controlCharacters) == nil
			else { throw LauncherError.invalidResponse }
			return header
		}
		return InstallerResumeMetadata(
			manifestHash: manifestHash,
			entityTag: try value("ETag"),
			lastModified: try value("Last-Modified")
		)
	}

	private static var resumeMetadataStore: JSONFileStore {
		JSONFileStore(
			maximumBytes: AppConstants.Game.installerResumeMetadataMaximumBytes,
			prettyPrinted: false
		)
	}

	func resumeMetadataFile(
		for relativePath: String,
		in stagingDirectory: InstallerDirectory
	) -> InstallerFile {
		let digest = SHA256.hash(data: Data(relativePath.utf8)).hexString
		return stagingDirectory.file(named: "resume-\(digest).json")
	}

	func readResumeMetadata(
		at file: InstallerFile
	) throws -> InstallerResumeMetadata? {
		guard let status = try file.stat() else { return nil }
		guard status.st_mode & S_IFMT == S_IFREG, status.st_nlink == 1 else {
			throw InstallerError.unsafeInstallerTemporaryFile(file.url)
		}
		let descriptor = try file.open(flags: O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
		defer { _ = close(descriptor) }
		do {
			return try Self.resumeMetadataStore.read(
				InstallerResumeMetadata.self,
				fileDescriptor: descriptor,
				at: file.url
			)
		} catch is DecodingError {
			log?.debug("Ignoring invalid installer resume metadata at \(file.url.path)")
			try file.unlink()
			return nil
		}
	}

	func writeResumeMetadata(
		_ metadata: InstallerResumeMetadata,
		to file: InstallerFile
	) throws {
		do {
			try Self.resumeMetadataStore.write(metadata, to: file.url)
		} catch JSONFileStoreError.tooLarge {
			throw LauncherError.invalidResponse
		}
	}
}
