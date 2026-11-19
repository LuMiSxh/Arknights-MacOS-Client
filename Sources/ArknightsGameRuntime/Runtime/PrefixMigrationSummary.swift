// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation

/// Reads a Wine prefix's migration state for diagnostics. It never runs or changes a migration.
package enum PrefixMigrationSummary {
	/// The completed migrations of `prefixDirectory`, or nil when the prefix has no state file.
	@concurrent
	package static func read(
		prefixDirectory: URL
	) async throws -> DiagnosticsEnvironment.PrefixMigrations? {
		guard let state = try RuntimeMigrationStore().load(from: prefixDirectory) else {
			return nil
		}
		let stateFile = prefixDirectory.appending(path: RuntimeMigrationStore.stateFileName)
		return DiagnosticsEnvironment.PrefixMigrations(
			runtimeRevision: state.runtimeRevision,
			completed: state.completed.map(\.rawValue),
			updatedAt: try stateFile.resourceValues(forKeys: [.contentModificationDateKey])
				.contentModificationDate
		)
	}
}
