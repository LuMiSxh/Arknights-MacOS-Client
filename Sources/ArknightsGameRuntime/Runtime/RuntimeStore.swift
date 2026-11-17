// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsInfrastructure
import Foundation

package enum RuntimeStoreError: Error, Equatable, Sendable {
	case cannotRemoveSelectedLane(RuntimeLane)
	case laneNotAllowed(RuntimeLane)
}

/// Owns the managed runtime trees under `AppPaths.runtimeRoot`. There is one directory per lane
/// and version, at `Runtimes/<lane>-<version>/`. `runtime.json` records the installed version of
/// each lane, so no directory scan decides what is installed. A missing or corrupt document is
/// rebuilt from the version directories that hold a valid `RUNTIME.json`. Every write goes through
/// `RuntimeSelectionStore.update` on the shared owner, so concurrent writers never drop each
/// other's entries.
package struct RuntimeStore: Sendable {
	package let paths: AppPaths

	private let selectionStore: RuntimeSelectionStore

	package init(paths: AppPaths, selectionStore: RuntimeSelectionStore) {
		self.paths = paths
		self.selectionStore = selectionStore
	}

	/// Rebuilds a missing or corrupt document from disk so an existing install is not lost.
	package func recoverRecordIfNeeded() throws {
		try selectionStore.recoverIfNeeded(recovering: installedVersionsOnDisk)
	}

	/// The version directory that holds the lane's installed `RUNTIME.json`.
	package func installedVersion(for lane: RuntimeLane) -> String? {
		paths.installedRuntimeVersion(for: lane)
	}

	package func select(
		lane: RuntimeLane,
		access: RuntimeAccess = RuntimeAccess()
	) throws {
		guard access.allows(lane) else {
			throw RuntimeStoreError.laneNotAllowed(lane)
		}
		try selectionStore.update(access: access, recovering: installedVersionsOnDisk) {
			$0.selected = lane
		}
	}

	/// Records a completed install in the runtime document.
	package func recordInstalled(lane: RuntimeLane, version: String) throws {
		try selectionStore.update(recovering: installedVersionsOnDisk) {
			$0.installedVersions[lane] = version
		}
	}

	/// Removes the lane's version directories under the lane lease. The record changes first, so
	/// a failed delete never leaves a record that names a missing runtime. The selected lane is
	/// refused unless `allowSelected` is set; the selection itself stays either way.
	package func remove(lane: RuntimeLane, allowSelected: Bool = false) throws {
		try withInstallLease(at: paths.runtimeLeaseDirectory(for: lane)) { _ in
			try selectionStore.update(recovering: installedVersionsOnDisk) { selection in
				if !allowSelected, selection.selected == lane {
					throw RuntimeStoreError.cannotRemoveSelectedLane(lane)
				}
				selection.installedVersions[lane] = nil
			}
			for version in try versionNames(for: lane) {
				try removeItem(at: paths.runtimeVersionDirectory(for: lane, version: version))
			}
		}
	}

	/// Deletes every installed version of a pinned lane that does not match this pin, and drops
	/// the record entries it deletes. Lanes without a pin are left untouched, so an unpublished
	/// lane never loses user data. The caller holds the lane lease.
	package func cleanup(pinned: [RuntimeLane: String]) throws {
		var stale: [(lane: RuntimeLane, version: String)] = []
		for (lane, version) in pinned {
			for installed in try versionNames(for: lane) where installed != version {
				stale.append((lane, installed))
			}
		}
		guard !stale.isEmpty else { return }
		try selectionStore.update(recovering: installedVersionsOnDisk) { selection in
			for (lane, version) in stale where selection.installedVersions[lane] == version {
				selection.installedVersions[lane] = nil
			}
		}
		for (lane, version) in stale {
			try removeItem(at: paths.runtimeVersionDirectory(for: lane, version: version))
		}
	}

	// MARK: - Private

	/// The highest version directory per lane that holds a valid `RUNTIME.json`.
	private func installedVersionsOnDisk() throws -> [RuntimeLane: String] {
		var versions: [RuntimeLane: String] = [:]
		for lane in RuntimeLane.allCases {
			let valid = try versionNames(for: lane).filter { version in
				hasValidManifest(
					at: paths.runtimeVersionDirectory(for: lane, version: version))
			}
			if let highest = valid.max(by: {
				$0.compare($1, options: .numeric) == .orderedAscending
			}) {
				versions[lane] = highest
			}
		}
		return versions
	}

	private func hasValidManifest(at directory: URL) -> Bool {
		do {
			let data = try BoundedFileReader.readRegularFile(
				at: directory.appending(path: "RUNTIME.json"),
				maximumBytes: AppConstants.Game.runtimeMigrationStateMaximumBytes)
			return try JSONSerialization.jsonObject(with: data) is [String: Any]
		} catch {
			// An unreadable or malformed manifest means this directory is not a usable install.
			return false
		}
	}

	private func versionNames(for lane: RuntimeLane) throws -> [String] {
		let prefix = "\(lane.rawValue)-"
		let entries: [URL]
		do {
			entries = try FileManager.default.contentsOfDirectory(
				at: paths.runtimeRoot,
				includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey]
			)
		} catch  where AppPaths.isMissingPathError(error) {
			return []
		}
		return try entries.compactMap { entry in
			let values = try entry.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
			guard values.isDirectory == true, values.isSymbolicLink != true else { return nil }
			let name = entry.lastPathComponent
			guard name.hasPrefix(prefix) else { return nil }
			return String(name.dropFirst(prefix.count))
		}
	}

	private func removeItem(at url: URL) throws {
		do {
			try FileManager.default.removeItem(at: url)
		} catch  where AppPaths.isMissingPathError(error) {
			return
		}
	}
}
