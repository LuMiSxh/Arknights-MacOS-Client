// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsInfrastructure
import Foundation

extension GameInstaller {
	static func fetchRemoteResources(
		_ operation: @Sendable () async throws -> (GameManifest, CDNConfiguration)
	) async throws -> (GameManifest, CDNConfiguration) {
		do {
			return try await operation()
		} catch {
			let resolved = HTTPCancellation.resolve(error)
			if let transportError = resolved as? HTTPTransportError {
				throw Self.launcherError(for: transportError)
			}
			throw resolved
		}
	}

	package static func launcherError(for transportError: HTTPTransportError) -> any Error {
		switch transportError {
		case .responseTooLarge(let url, let maximumBytes):
			LauncherError.remoteContentTooLarge(url, maximumBytes: maximumBytes)
		case .responseSizeMismatch(let url, let expected, let actual):
			InstallerError.downloadedSizeMismatch(
				path: url.absoluteString, expected: expected, actual: actual)
		case .invalidResponse, .redirectRejected:
			LauncherError.invalidResponse
		}
	}

	// Normal updates trust the previous manifest's checksum after a size check. Repair, and
	// installs created before file metadata was recorded, hash the destination instead.
	static func needsDownload(
		_ item: ManifestFile,
		destinationSize: Int64?,
		previousFile: ManifestFile?,
		verifyAllExistingFiles: Bool,
		checksum: () throws -> String
	) rethrows -> Bool {
		guard destinationSize == item.byteCount else { return true }

		if verifyAllExistingFiles || previousFile == nil {
			return try checksum() != item.hash
		}

		return previousFile?.hash != item.hash
	}
}
