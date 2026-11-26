// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsInfrastructure
import Foundation

/// The manifest files that a verification pass found damaged or missing, in manifest order.
package struct GameFileVerification: Sendable, Equatable {
	package let damagedPaths: [String]
}

extension GameInstaller {
	/// Hashes the installed files against the manifest. Downloads, renames, and deletes nothing.
	package func verify(
		configuration: GameConfiguration,
		region: GameRegion,
		in installDirectory: URL,
		progress: @escaping ProgressHandler
	) async throws -> GameFileVerification {
		// Only lease acquisition gets the lease mapping; body errors keep their own type.
		var leaseAcquired = false
		do {
			return try await withInstallLease(at: installDirectory) { lease in
				leaseAcquired = true
				let manifest = try await Self.fetchRemoteResources {
					try await api.manifest(for: configuration, region: region)
				}
				try validateManifestPaths(manifest)
				let verification = try await pendingDownloads(
					in: manifest,
					installDirectory: lease.directory,
					previousFiles: nil,
					verifyAllExistingFiles: true,
					progress: progress
				)
				return GameFileVerification(damagedPaths: verification.files.map(\.path))
			}
		} catch {
			throw leaseAcquired ? error : mapInstallerFileSystemError(error)
		}
	}
}
