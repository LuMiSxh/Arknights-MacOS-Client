// SPDX-License-Identifier: MPL-2.0

import Foundation

@testable import ArknightsGameInstallation
@testable import ArknightsInfrastructure

/// Holds the install lease for `root` while `body` runs, then releases it before returning or throwing.
func withTestInstallDirectory<R>(
	at root: URL,
	_ body: (InstallerDirectory) async throws -> R
) async throws -> R {
	try await withInstallLease(at: root) { (lease: borrowing InstallLease) async throws -> R in
		try await body(lease.directory)
	}
}
