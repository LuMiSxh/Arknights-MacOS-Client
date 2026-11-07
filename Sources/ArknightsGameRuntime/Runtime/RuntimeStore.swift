// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsInfrastructure
import Foundation

package enum RuntimeStoreError: Error, Equatable, Sendable {
	case cannotRemoveSelectedLane(RuntimeLane)
	case laneNotAllowed(RuntimeLane)
}

/// Owns the managed runtime trees under `AppPaths.runtimeRoot`. There is exactly one installed
/// runtime per lane, at `Runtimes/<lane>/<version>/`; the pinned version decides the directory
/// name, so an install replaces the lane's previous tree.
///
/// The only persisted choice is `RuntimeSelection.selected`.
package struct RuntimeStore: Sendable {
	package let paths: AppPaths

	private let selectionStore: RuntimeSelectionStore

	package init(paths: AppPaths) {
		self.paths = paths
		selectionStore = RuntimeSelectionStore(fileURL: paths.runtimeSelectionFile)
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
		try selectionStore.save(RuntimeSelection(selected: lane))
	}

	/// Removes the whole lane directory. The selected lane cannot be removed.
	package func remove(lane: RuntimeLane) throws {
		let selection = try selectionStore.load()
		guard selection.selected != lane else {
			throw RuntimeStoreError.cannotRemoveSelectedLane(lane)
		}
		try withInstallLease(at: paths.runtimeDirectory(for: lane)) { _ in
			try removeItem(at: paths.runtimeDirectory(for: lane))
		}
	}

	/// Deletes every installed version of a pinned lane that does not match this pin. Lanes
	/// without a pin are left untouched, so an unpublished lane never loses user data.
	package func cleanup(pinned: [RuntimeLane: String]) throws {
		for (lane, version) in pinned {
			let laneDirectory = paths.runtimeDirectory(for: lane)
			for installed in try versionNames(in: laneDirectory) where installed != version {
				try removeItem(
					at: laneDirectory.appending(
						path: installed, directoryHint: .isDirectory)
				)
			}
		}
	}

	// MARK: - Private

	private func versionNames(in laneDirectory: URL) throws -> [String] {
		let entries: [URL]
		do {
			entries = try FileManager.default.contentsOfDirectory(
				at: laneDirectory,
				includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey]
			)
		} catch  where AppPaths.isMissingPathError(error) {
			return []
		}
		return try entries.compactMap { entry in
			let values = try entry.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
			guard values.isDirectory == true, values.isSymbolicLink != true else { return nil }
			return entry.lastPathComponent
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
