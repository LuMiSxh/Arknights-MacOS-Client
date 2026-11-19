// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsInfrastructure
import Foundation

/// Reads the install state file for diagnostics without keeping its file list.
package enum InstalledStateSummary {
	/// The summary of the install state in `directory`, or nil when the game has none.
	@concurrent
	package static func read(in directory: URL) async throws -> DiagnosticsEnvironment.InstallState?
	{
		let url = directory.appending(path: AppConstants.Game.installedStateFileName)
		guard let state = try JSONFileStore.installedState.read(InstalledState.self, at: url)
		else { return nil }
		return DiagnosticsEnvironment.InstallState(
			schemaVersion: state.schemaVersion, version: state.version, basis: state.basis,
			source: state.source, installedAt: state.installedAt)
	}
}
