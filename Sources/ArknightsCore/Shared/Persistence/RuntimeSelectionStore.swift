// SPDX-License-Identifier: MPL-2.0

import ArknightsInfrastructure
import Foundation
import Synchronization

/// Reads and writes the small runtime document: the chosen lane and each lane's installed version.
///
/// The launcher creates one instance per document and shares it with every writer. It is a class
/// because the lock is `~Copyable` state that all holders must share.
package final class RuntimeSelectionStore: Sendable {
	package let fileURL: URL

	/// Serializes every read-modify-write of the document through this owner. The per-lane install
	/// leases do not cover it, because both lanes share one file. One launcher instance runs at a
	/// time, so no cross-process lock is needed. The lock never spans an `await`.
	private let writeLock = Mutex<Void>(())

	private let files = JSONFileStore(
		maximumBytes: AppConstants.Runtime.runtimeSelectionMaximumBytes
	)
	private let log: LauncherLog?

	package init(fileURL: URL, log: LauncherLog? = nil) {
		self.fileURL = fileURL
		self.log = log
	}

	/// Returns the persisted selection, or the OS default when no file exists.
	package func load(access: RuntimeAccess = RuntimeAccess()) throws -> RuntimeSelection {
		try files.read(RuntimeSelection.self, at: fileURL)
			?? RuntimeSelection(selected: access.defaultLane)
	}

	package func save(_ selection: RuntimeSelection) throws {
		try files.write(selection, to: fileURL, createParentDirectory: true)
	}

	/// Runs `body` under the write lock. Use it for a read-modify-write that `update` cannot express.
	package func withExclusiveAccess<T>(_ body: () throws -> T) rethrows -> T {
		try writeLock.withLock { _ in try body() }
	}

	/// Loads, mutates, and saves the document under the write lock. A missing or
	/// unreadable document restarts from the default lane plus `recovering`'s installed versions.
	/// A throwing `mutate` leaves the file untouched.
	package func update(
		access: RuntimeAccess = RuntimeAccess(),
		recovering: () throws -> [RuntimeLane: String] = { [:] },
		_ mutate: (inout RuntimeSelection) throws -> Void
	) throws {
		try withExclusiveAccess {
			var selection = try loadOrRecover(access: access, recovering: recovering).selection
			try mutate(&selection)
			try save(selection)
		}
	}

	/// Rewrites a corrupt document, or writes one rebuilt from disk when the file is missing and
	/// `recovering` finds installed versions. A readable document is left alone.
	package func recoverIfNeeded(
		access: RuntimeAccess = RuntimeAccess(),
		recovering: () throws -> [RuntimeLane: String]
	) throws {
		try withExclusiveAccess {
			let loaded = try loadOrRecover(access: access, recovering: recovering)
			if loaded.needsSave { try save(loaded.selection) }
		}
	}

	private func loadOrRecover(
		access: RuntimeAccess,
		recovering: () throws -> [RuntimeLane: String]
	) throws -> (selection: RuntimeSelection, needsSave: Bool) {
		let existing: RuntimeSelection?
		var unreadable = false
		do {
			existing = try files.read(RuntimeSelection.self, at: fileURL)
		} catch {
			// A damaged document must not block installs; the version directories are the truth.
			log?.error(
				"Runtime document at \(fileURL.path) is unreadable and will be rebuilt: "
					+ launcherDiagnosticDescription(for: error))
			existing = nil
			unreadable = true
		}
		if let existing { return (existing, false) }
		let recovered = try recovering()
		return (
			RuntimeSelection(selected: access.defaultLane, installedVersions: recovered),
			unreadable || !recovered.isEmpty
		)
	}
}
