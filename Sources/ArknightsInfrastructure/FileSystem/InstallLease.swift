// SPDX-License-Identifier: MPL-2.0

import Darwin
import Foundation

/// Exclusive cross-process advisory lease on an install root.
///
/// The lease owns a descriptor on the root with an `flock`. `flock` binds to the open file
/// description, so a second acquire conflicts even inside this process.
/// Call ``release()`` to unlock and close deterministically; `deinit` only backs that up.
package struct InstallLease: ~Copyable, Sendable {
	package let directory: InstallerDirectory
	private let lockDescriptor: Int32

	/// Creates the install root and takes its lock, or throws `directoryInUse` while another holder has it.
	static func acquire(at url: URL) throws -> InstallLease {
		try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
		let directory = InstallerDirectory(at: url)
		let descriptor = open(directory.url.path, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
		guard descriptor >= 0 else {
			if errno == ELOOP { throw InstallerFileSystemError.symbolicLink(directory.url) }
			throw POSIXError(.init(rawValue: errno) ?? .EIO)
		}
		guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
			let error = errno
			_ = close(descriptor)
			if error == EWOULDBLOCK || error == EAGAIN {
				throw InstallerFileSystemError.directoryInUse(directory.url)
			}
			throw POSIXError(.init(rawValue: error) ?? .EIO)
		}
		return InstallLease(directory: directory, lockDescriptor: descriptor)
	}

	/// Ends the lease now; consuming `self` runs `deinit`, the single unlock path.
	consuming func release() {}

	deinit {
		_ = flock(lockDescriptor, LOCK_UN)
		_ = close(lockDescriptor)
	}
}

/// Runs `body` while holding the install lease, and releases it before returning or throwing.
package func withInstallLease<R>(
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

package func withInstallLease<R>(
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
