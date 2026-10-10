// SPDX-License-Identifier: MPL-2.0

import Darwin
import Foundation

/// Exclusive cross-process advisory lease on an install root.
///
/// The lease owns a separate lock descriptor whose device and inode match the pinned root.
/// Call ``release()`` to unlock and close deterministically; `deinit` only backs that up.
struct InstallLease: ~Copyable, Sendable {
	let directory: InstallerInstallDirectory
	private let lockDescriptor: Int32

	/// Pins the install root and takes its lock, or throws `directoryInUse` while another holder has it.
	static func acquire(at url: URL) throws -> InstallLease {
		let directory = try InstallerInstallDirectory(pinningAt: url)
		let descriptor = try InstallerInstallDirectory.acquireLock(on: directory.root)
		return InstallLease(directory: directory, lockDescriptor: descriptor)
	}

	/// Ends the lease now; consuming `self` runs `deinit`, the single unlock path.
	consuming func release() {}

	deinit {
		InstallerInstallDirectory.releaseLock(lockDescriptor)
	}
}

/// Runs `body` while holding the install lease, and releases it before returning or throwing.
func withInstallLease<R>(
	at url: URL,
	_ body: (borrowing InstallLease) throws -> R
) throws -> R {
	let lease = try InstallLease.acquire(at: url)
	do {
		let result = try body(lease)
		lease.release()
		return result
	} catch {
		lease.release()
		throw error
	}
}

func withInstallLease<R>(
	at url: URL,
	isolation: isolated (any Actor)? = #isolation,
	_ body: (borrowing InstallLease) async throws -> R
) async throws -> R {
	let lease = try InstallLease.acquire(at: url)
	do {
		let result = try await body(lease)
		lease.release()
		return result
	} catch {
		lease.release()
		throw error
	}
}
