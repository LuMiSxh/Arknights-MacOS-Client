// SPDX-License-Identifier: MPL-2.0

import Foundation

extension GameInstaller {
	static func fetchRemoteResources(
		_ operation: @Sendable () async throws -> (GameManifest, CDNConfiguration)
	) async throws -> (GameManifest, CDNConfiguration) {
		do {
			return try await operation()
		} catch is CancellationError {
			throw CancellationError()
		} catch let error as HTTPTransportError {
			if Task.isCancelled { throw CancellationError() }
			throw Self.launcherError(for: error)
		}
	}

	static func launcherError(for transportError: HTTPTransportError) -> LauncherError {
		switch transportError {
		case .responseTooLarge(let url, let maximumBytes):
			.remoteContentTooLarge(url, maximumBytes: maximumBytes)
		case .invalidResponse, .redirectRejected:
			.invalidResponse
		}
	}

	/// Decides whether an existing destination can be reused for the supplied manifest entry.
	///
	/// Normal updates trust the checksum stored in the previous manifest after confirming the
	/// file size. Repair mode, and installations created before file metadata was recorded,
	/// verify the destination checksum instead.
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
