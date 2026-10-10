// SPDX-License-Identifier: MPL-2.0

import Foundation

@testable import ArknightsClient

/// Holds the install lease for `root` while `body` runs, then releases it before returning or throwing.
func withTestInstallDirectory<R>(
	at root: URL,
	_ body: (InstallerInstallDirectory) async throws -> R
) async throws -> R {
	try await withInstallLease(at: root) { (lease: borrowing InstallLease) async throws -> R in
		try await body(lease.directory)
	}
}
